--- Opt-in builder receipt: caller-owned transport, never independent authority.
local child = require("cosmic.child")
local fs = require("cosmic.fs")
local claim = require("_work.claim")
local claimbatch = require("_work.claimbatch")
local claimcli = require("_work.gitclaim_cli")
local claimsession = require("_work.claimsession")
local gitclaim = require("_work.gitclaim")
local gitdraft = require("_work.gitdraft")
local batchcheck = require("_work.gitfsck_claimbatch")
local item = require("_work.item")
local ksuid = require("_work.ksuid")
local refs = require("_work.refs")
local repository_map = require("_work.repository_map")
local store = require("_work.store")

local VERSION < const > = "gitboard-builder-preparation-v1"
local KEYS < const > = {"format", "board-root", "board-mode", "board-remote",
  "item", "session", "claim-fact", "claim-control", "product-base",
  "product-root", "branch", "worktree", "bootstrap", "gitboard-command", "gitboard-cwd"}

local function escape(value: string): string
  return (value:gsub("\\", "\\\\"):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t"))
end

local function shape(values: {string: string}): string
  local seen = 0
  for _ in pairs(values) do seen = seen + 1 end
  if seen ~= #KEYS then return "receipt has extra or missing keys" end
  for _, key in ipairs(KEYS) do
    local v = values[key]
    if v == nil or v:find("\0", 1, true) then return "invalid receipt value: " .. key end
    if v == "" and key ~= "board-remote" and key ~= "gitboard-command"
    and key ~= "gitboard-cwd" then return "empty receipt value: " .. key end
  end
  if values.format ~= VERSION then return "unsupported preparation receipt version" end
  local mode = values["board-mode"]
  if mode ~= "local" and mode ~= "remote" then return "invalid board mode" end
  if (mode == "local") ~= (values["board-remote"] == "") then return "invalid board remote" end
  if not ksuid.is_id(values.item) then return "invalid receipt item" end
  if not claimsession.is_id(values.session) then return "invalid receipt session" end
  for _, key in ipairs({"claim-fact", "claim-control", "product-base"}) do
    local v = values[key]
    if #v ~= 40 or not v:match("^[0-9a-f]+$") then return "invalid receipt SHA: " .. key end
  end
  if values.branch ~= claim.branch(values.item, values["claim-fact"]) then
    return "receipt branch does not match acquisition"
  end
  if (values["gitboard-command"] == "") ~= (values["gitboard-cwd"] == "") then
    return "invocation command and cwd must be supplied together"
  end
  if values["gitboard-command"]:find("[\r\n]") then return "invocation must be one line" end
  return ""
end

--- @return string Canonical bytes, empty on failure
--- @return string Error message
local function encode(values: {string: string}): string, string
  local err = shape(values)
  if err ~= "" then return "", err end
  local lines: {string} = {}
  for _, key in ipairs(KEYS) do lines[#lines + 1] = key .. "=" .. escape(values[key]) end
  return table.concat(lines, "\n") .. "\n", ""
end

--- @return {string: string} Decoded fields, empty on failure
--- @return string Error message
local function decode(text: string): {string: string}, string
  local values: {string: string} = {}
  local escapes: {string: string} = {["\\"] = "\\", n = "\n", r = "\r", t = "\t"}
  local n = 0
  for line in text:gmatch("([^\n]*)\n") do
    n = n + 1
    local key, raw = line:match("^([^=]+)=(.*)$")
    if key == nil or raw == nil or key ~= KEYS[n] then return {}, "noncanonical receipt keys" end
    local out: {string} = {}
    local i = 1
    while i <= #raw do
      local c = raw:sub(i, i)
      if c == "\\" then
        i = i + 1
        local escaped = raw:sub(i, i)
        local decoded = escapes[escaped]
        if decoded == nil then return {}, "invalid receipt escape" end
        c = decoded
      end
      out[#out + 1] = c
      i = i + 1
    end
    values[key] = table.concat(out)
  end
  local canonical, err = encode(values)
  if err ~= "" then return {}, err end
  if canonical ~= text then return {}, "noncanonical receipt bytes" end
  return values, ""
end

--- Recover and validate the Git-backed lease which authorizes local work.
--- Looking at the durable holder field alone is insufficient: ordinary item
--- mutations may sit above the control commit, and a two-hour lease can have
--- expired without rewriting the item. The returned root is the stable branch
--- identity; renewals change only the control/deadline.
local function active_claim(s: store.Store, it: item.Item, session: string):
  claim.State | nil, string
  local holder = it.claim or ""
  if holder == "" then
    return nil, ("REFUSED: %s is not claimed by %s — claim it first")
    :format(it.id:sub(-8), session)
  end
  local pointer = it.claim_batch or ""
  if pointer == "" then return nil, "item has no claim batch" end
  local st, err = claimbatch.read_state(s.root, pointer, it.id)
  if err ~= "" then return nil, err end
  local status = claim.status(st, os.time())
  if status ~= "active" then
    if status == "future" then
      return nil, "REFUSED: claim timestamp is more than five minutes in the future"
    end
    return nil, ("REFUSED: %s's claim has expired — claim it again")
    :format(it.id:sub(-8))
  end
  if st == nil then return nil, "active claim has no state" end
  if st.holder ~= session then
    return nil, ("REFUSED: %s is claimed by %s, not %s")
    :format(it.id:sub(-8), st.holder, session)
  end
  return st, ""
end

--- @return string Refusal, empty when the receipt options are valid
local function options(file: string, command: string, cwd: string, review: boolean): string
  if file == "" then
    if command ~= "" or cwd ~= "" then return "invocation flags require --receipt-out" end
    return ""
  end
  if file == "-" then return "--receipt-out needs an explicit file path" end
  if review then return "--receipt-out supports builders only" end
  if (command == "") ~= (cwd == "") then return "invocation command and cwd must be supplied together" end
  if command:find("[\0\r\n]") then return "invocation must be one line without NUL" end
  if cwd ~= "" and not fs.is_dir(cwd) then return "invocation cwd is not a directory" end
  return ""
end

--- @return claim.State | nil The current, fully confirmed active claim
--- @return string Refusal
local function confirmed(s: store.Store, it: item.Item, session: string): claim.State | nil, string
  if refs.has_overlay(s.root) or gitdraft.active(s.root) ~= nil then
    return nil, "preparation receipts refuse draft/overlay state"
  end
  if not claimsession.is_id(session) then return nil, "receipt needs a minted session" end
  local st, err = active_claim(s, it, session)
  if st == nil then return nil, err end
  local problems = batchcheck.problems(s)
  if #problems > 0 then return nil, table.concat(problems, "\n") end
  local pending, perr = gitclaim.list_prepared(s.root, refs.board_remote(s.root))
  if pending == nil then return nil, perr end
  for _, p in ipairs(pending) do
    if p.batch.commit == st.control then return nil, "claim confirmation pending; complete refresh first" end
  end
  return st, ""
end

--- @return string Receipt write error, empty on success
local function write(s: store.Store, it: item.Item, st: claim.State,
    source: string, branch: string, path: string, bootstrap: string,
    file: string, command: string, cwd: string): string
  local mode = refs.board_mode(s.root)
  local values: {string: string} = {
    format = VERSION, ["board-root"] = fs.absolute_path(s.root),
    ["board-mode"] = mode, ["board-remote"] = mode == "local" and "" or refs.board_remote(s.root),
    item = it.id, session = st.holder, ["claim-fact"] = st.root,
    ["claim-control"] = st.control, ["product-base"] = st.product_base,
    ["product-root"] = fs.absolute_path(source), branch = branch,
    worktree = fs.absolute_path(path), bootstrap = bootstrap,
    ["gitboard-command"] = command, ["gitboard-cwd"] = cwd ~= "" and fs.absolute_path(cwd) or "",
  }
  local text, err = encode(values)
  if err ~= "" then return err end
  local ok, werr = fs.write(file, text)
  return ok and "" or ("could not write receipt %s: %s"):format(file, werr)
end

local function git_value(path: string, argv: {string}): string, string
  local r, err = child.run({"git", table.unpack(argv)}, {cwd = path})
  if r == nil then return "", err end
  if not r.ok then return "", r.stderr end
  return (r.stdout:gsub("%s+$", "")), ""
end

local function checkout(values: {string: string}, tree: string): string
  local source, serr = repository_map.validate(values["product-root"])
  if source == nil then return serr end
  local path, perr = repository_map.validate(values.worktree)
  if path == nil then return perr end
  if source ~= values["product-root"] or path ~= values.worktree then
    return "receipt paths are not exact Git toplevels"
  end
  if tree ~= "" then
    local measured = repository_map.validate(tree)
    if measured ~= path then return "--tree does not match preparation worktree" end
  end
  local head, herr = git_value(path, {"rev-parse", "--verify", "HEAD^{commit}"})
  if head ~= values["product-base"] then return "receipt checkout HEAD mismatch: " .. herr end
  local branch, berr = git_value(path, {"symbolic-ref", "--short", "HEAD"})
  if branch ~= values.branch then return "receipt checkout branch mismatch: " .. berr end
  local common, cerr = git_value(source, {"rev-parse", "--path-format=absolute", "--git-common-dir"})
  if common == "" then return cerr end
  local other, oerr = git_value(path, {"rev-parse", "--path-format=absolute", "--git-common-dir"})
  if other ~= common then return "receipt checkout repository mismatch: " .. oerr end
  return ""
end

--- @return {string: string} Validated receipt, empty for the legacy path or failure
--- @return string Refusal
local function read(s: store.Store, it: item.Item, kind: string, file: string,
    caller: string, tree: string): {string: string}, string
  if file == "" then
    if caller ~= "" then return {}, "--session requires a builder --receipt" end
    return {}, ""
  end
  if kind ~= "builder" then return {}, "--receipt supports builders only" end
  local session, serr = claimcli.resolve_caller(caller)
  if session == nil then return {}, serr end
  local text, ferr = fs.read(file)
  if text == nil then return {}, ferr end
  local values, derr = decode(text)
  if derr ~= "" then return {}, derr end
  local st, err = confirmed(s, it, session)
  if st == nil then return {}, err end
  local mode = refs.board_mode(s.root)
  local remote = mode == "local" and "" or refs.board_remote(s.root)
  if values["board-root"] ~= fs.absolute_path(s.root) or values["board-mode"] ~= mode
  or values["board-remote"] ~= remote or values.item ~= it.id or values.session ~= session
  or values["claim-fact"] ~= st.root or values["product-base"] ~= st.product_base then
    return {}, "preparation receipt does not match current claim"
  end
  local old, oerr = claimbatch.read_state(s.root, values["claim-control"], it.id)
  if old == nil then return {}, "receipt control unavailable: " .. oerr end
  if old.holder ~= st.holder or old.root ~= st.root or old.product_base ~= st.product_base then
    return {}, "receipt control does not match acquisition"
  end
  local batch, berr = claimbatch.read(s.root, values["claim-control"])
  if batch == nil then return {}, berr end
  local canonical = refs.canonical_ref(s.root, gitclaim.batch_ref(batch.id))
  local observed = canonical ~= nil and refs.read_ref(s.root, canonical) or ""
  if observed ~= values["claim-control"] then return {}, "receipt control is not canonical" end
  local invalid = checkout(values, tree)
  if invalid ~= "" then return {}, invalid end
  return values, ""
end

--- @return string Provenance text, with receipt values preserved as escaped data
local function context(values: {string: string}): string
  local text = encode(values)
  local fence = "~~~"
  for run in text:gmatch("~+") do if #run >= #fence then fence = run .. "~" end end
  local invocation = values["gitboard-command"] == "" and "Invocation unspecified."
  or "Caller-provided invocation (not verified): gitboard-command and gitboard-cwd below."
  return "Bootstrap status records process success or explicit\n"
  .. "skipping; runtime invocation, digest and artifact readiness are unverified.\n\n"
  .. "claim-fact is the acquisition; claim-control is preparation-time control.\n"
  .. "bootstrap is historical process status, not artifact validation.\n"
  .. invocation .. "\n\n" .. fence .. "\n" .. text .. fence
end

local record preparation_receipt
  encode: function(values: {string: string}): string, string
  decode: function(text: string): {string: string}, string
  active_claim: function(s: store.Store, it: item.Item, session: string): claim.State | nil, string
  options: function(file: string, command: string, cwd: string, review: boolean): string
  confirmed: function(s: store.Store, it: item.Item, session: string): claim.State | nil, string
  write: function(s: store.Store, it: item.Item, st: claim.State,
  source: string, branch: string, path: string, bootstrap: string,
  file: string, command: string, cwd: string): string
  read: function(s: store.Store, it: item.Item, kind: string, file: string,
  caller: string, tree: string): {string: string}, string
  context: function(values: {string: string}): string
end

local M: preparation_receipt = {encode = encode, decode = decode,
  active_claim = active_claim, options = options, confirmed = confirmed,
  write = write, read = read, context = context}
return M
