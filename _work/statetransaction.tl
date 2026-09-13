--- Canonical, immutable format-6 ordered transaction snapshots.
local literal = require("_work.singlehead_literal")
local objects = require("_work.singlehead_objects")
local fs = require("cosmic.fs")
local saved = require("_work.stateplan_file")
local trailer_codec = require("_work.stateplan_trailers")
local record Dependency
  path: string
  id: string
end
local record Change
  path: string
  mode: string
  content: string
  delete: boolean
end
local record Author
  name: string
  email: string
  date: string
end
local record Transition
  base: string
  dependencies: {Dependency}
  changes: {Change}
  message: string
  author: Author
  publish_by: integer
  bounded: boolean
  gate: string
end
local record Frozen
  format: string
  repository: string
  branch: string
  remote: string
  transaction: string
  staging_sha: string
  transitions: {Transition}
end
local FORMAT < const > = "gitboard-state-transaction-v1"
--- Whether a path may appear in a transition: relative, non-empty, with no
--- traversal, no doubled or trailing separator, and no control characters —
--- checked here rather than at the writer, so a saved attempt cannot name a
--- path some later executor would resolve differently.
--- @param path string A tree path from a change or dependency
--- @return boolean True when the path is acceptable
local function path_ok(path: string): boolean
  return path ~= "" and path:sub(1, 1) ~= "/" and path:sub(-1) ~= "/"
  and not path:find("[%z\n\r\t]") and not path:find("//", 1, true)
  and not ("/" .. path .. "/"):find("/../", 1, true)
  and not ("/" .. path .. "/"):find("/./", 1, true)
end
--- @param value Frozen transaction, including its exact destination and chain.
--- @param assembling Permit absent reserved trailers only before initial freezing.
--- @return Whether all fields and reserved trailer identities are coherent.
local function validate(value: Frozen, assembling?: boolean): boolean, string
  if value.format ~= FORMAT then return false, "unsupported state transaction" end
  local repository = objects.checked_repository(value.repository)
  local branch = objects.checked_branch(value.branch)
  if repository ~= value.repository or branch ~= value.branch or value.remote == ""
  or value.remote:find("[%s%z]") then return false, "invalid transaction destination" end
  if not objects.checked_sha(value.staging_sha, false)
  or not value.transaction:match("^[A-Za-z0-9_-]+$")
  or #value.transitions == 0 then return false, "invalid transaction identity" end
  for _, transition in ipairs(value.transitions) do
    local trailers, terr = trailer_codec.parse(transition.message)
    if trailers == nil then return false, terr end
    local logical: string | nil = nil
    local authors, transactions, transaction_id = 0, 0, ""
    for line in trailers:gmatch("([^\n]+)") do
      local key, trailer_value = line:match("^([^:]+):%s*(.*)$")
      if key ~= nil and key:lower() == "gitboard-author" then logical = trailer_value; authors = authors + 1 end
      if key ~= nil and key:lower() == "transaction" then transaction_id = trailer_value; transactions = transactions + 1 end
    end
    local encoded_author = literal.encode(transition.author)
    if logical ~= nil and logical ~= (encoded_author or ""):gsub("\n$", "") then
      return false, "logical author differs from frozen author"
    end
    if authors > 1 or transactions > 1 or (transactions == 1 and transaction_id ~= value.transaction)
    or (authors == 1 and transactions ~= 1) then
      return false, "reserved publication trailers conflict"
    end
    if not assembling and (transactions ~= 1 or authors ~= 1) then
      return false, "frozen transition requires exactly one Transaction and Gitboard-Author trailer"
    end
    if not objects.checked_sha(transition.base, false) or transition.publish_by < 0
    or (transition.bounded and transition.gate == "") then return false, "invalid transition fence" end
    if transition.author.name == "" or transition.author.email == "" or transition.author.date == ""
    or transition.author.name:find("[\n\r<>]") or transition.author.email:find("[\n\r<>]")
    or transition.author.date:find("[\n\r]") then return false, "invalid transition author" end
    local dependencies: {string: boolean} = {}
    for _, dependency in ipairs(transition.dependencies) do
      if not path_ok(dependency.path) or not objects.checked_sha(dependency.id, true)
      or dependencies[dependency.path] then return false, "invalid transition dependency" end
      dependencies[dependency.path] = true
    end
    local paths: {string: boolean} = {}
    for _, change in ipairs(transition.changes) do
      if not path_ok(change.path) or paths[change.path]
      or (change.mode ~= "100644" and change.mode ~= "100755" and change.mode ~= "120000")
      or (change.delete and change.content ~= "") then return false, "invalid transition change" end
      paths[change.path] = true
      local covered = dependencies[change.path] or false
      for path in pairs(dependencies) do
        if change.path:sub(1, #path + 1) == path .. "/" then covered = true end
      end
      if not covered then return false, "changed path lacks dependency: " .. change.path end
    end
    if #transition.changes == 0 then return false, "transition has no changes" end
  end
  return true, ""
end
--- A validated transaction as its canonical literal bytes.
--- @param value Frozen The transaction to encode
--- @return string | nil The canonical literal
--- @return string The validation refusal
local function encode(value: Frozen): string | nil, string
  local ok, err = validate(value)
  if not ok then return nil, err end
  return literal.encode(value)
end
--- A transaction back from its bytes, refusing anything that is not the
--- byte-identical canonical encoding of what it decodes to — so one saved
--- attempt has exactly one representation, and a hand-edited manifest is
--- refused rather than interpreted.
--- @param raw string The saved bytes
--- @return Frozen | nil The transaction
--- @return string Error message
local function decode(raw: string): Frozen | nil, string
  local value, err = literal.decode_object(raw)
  if value == nil then return nil, err end
  -- The protected validation also rejects malformed nested literal shapes.
  local frozen = value as Frozen -- cast: validated in protected call below
  local ran, valid, verr = pcall(validate, frozen)
  if not ran or not valid then return nil, ran and verr or "malformed state transaction" end
  local canonical = literal.encode(frozen)
  if canonical ~= raw then return nil, "transaction is not canonical" end
  return frozen, ""
end
--- @param value Staged transitions; supplied reserved trailers must already agree.
--- @return A copied, canonical chain whose reserved trailers are complete.
local function freeze(value: Frozen): Frozen | nil, string
  local ok, verr = validate(value, true)
  if not ok then return nil, verr end
  local raw, err = literal.encode(value)
  if raw == nil then return nil, err end
  local decoded, cerr = literal.decode_object(raw)
  if decoded == nil then return nil, cerr end
  local copy = decoded as Frozen -- cast: deep copy of the validated staged chain
  for _, transition in ipairs(copy.transitions) do
    local author = (literal.encode(transition.author) or ""):gsub("\n$", "")
    local message, merr = trailer_codec.bind(transition.message, copy.transaction, author)
    if message == nil then return nil, merr end
    transition.message = message
    table.sort(transition.changes, function(a: Change, b: Change): boolean return a.path < b.path end)
  end
  local valid, ferr = validate(copy)
  if not valid then return nil, ferr end
  return copy, ""
end
--- The attempt's digest, which is what a receipt records so a publication can
--- be compared against the attempt that was frozen rather than re-derived.
--- @param value Frozen The transaction
--- @return string | nil Its sha256 over the canonical bytes
--- @return string The validation refusal
local function digest(value: Frozen): string | nil, string
  local raw, err = encode(value)
  if raw == nil then return nil, err end
  return objects.sha256(raw), ""
end
--- Write a frozen attempt exactly once: a path that already holds one is
--- refused, never overwritten, because a second attempt at the same path would
--- make the first unverifiable.
--- @param path string Where to save it
--- @param value Frozen The transaction to freeze onto disk
--- @return boolean True when it was written
--- @return string Error message
local function save(path: string, value: Frozen): boolean, string
  local raw, err = encode(value)
  if raw == nil then return false, err end
  return saved.write_once(path, raw)
end
--- A saved attempt back from disk, through the same canonical decode.
--- @param path string The saved attempt's path
--- @return Frozen | nil The transaction
--- @return string Error message
local function load_saved(path: string): Frozen | nil, string
  local raw, err = fs.read(path)
  if raw == nil then return nil, err end
  return decode(raw)
end
local record Module
  type Dependency = Dependency
  type Change = Change
  type Author = Author
  type Transition = Transition
  type Frozen = Frozen
  FORMAT: string
  path_ok: function(string): boolean
  validate: function(Frozen): boolean, string
  encode: function(Frozen): string | nil, string
  decode: function(string): Frozen | nil, string
  freeze: function(Frozen): Frozen | nil, string
  digest: function(Frozen): string | nil, string
  save: function(string, Frozen): boolean, string
  load: function(string): Frozen | nil, string
end
local M: Module = {FORMAT = FORMAT, path_ok = path_ok, validate = validate, encode = encode, decode = decode,
  freeze = freeze, digest = digest, save = save, load = load_saved}
return M
