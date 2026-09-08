--- Git-backed claim preparation. This module performs no network operation:
--- it reads caller-fetched canonical refs, writes claim commits to staging
--- refs, and returns the leased push argv the caller may execute. Item refs do
--- not move locally until a later fetch confirms publication.
local child = require("cosmic.child")
local claim = require("_work.claim")
local format = require("_work.format")
local gitobj = require("_work.gitobj")
local gitread = require("_work.gitread")
local itemtree = require("_work.itemtree")
local refs = require("_work.refs")

local enum Action
  "take"
  "renew"
  "drop"
end

local record Request
  root: string
  id: string
  --- Caller-fetched canonical ref, normally refs/remotes/<remote>/items/ID.
  source_ref: string
  --- Shared destination, normally refs/heads/items/ID.
  target_ref: string
  remote: string
  batch: string
  caller: string
  action: Action
  product_base: string
  force: boolean
  why: string
  now: integer
end

local record Prepared
  id: string
  status: string -- "prepared" | "already-owned"
  old_sha: string
  new_sha: string
  staging_ref: string
  target_ref: string
  claim_root: string
  branch: string
  expires_at: integer
  push_argv: {string}
end

local record BatchResult
  prepared: {Prepared}
  already_owned: {Prepared}
  refused: {string: string}
end

local function clean_line(value: string): string
  return ((value or ""):gsub("[%c]+", " "):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function sha_refusal(value: string, field: string): string | nil
  if not (value or ""):match("^[0-9a-fA-F]+$") or #value ~= 40 then
    return field .. " must be a full 40-character commit id"
  end
  return nil
end

--- Conventional canonical ref after the caller fetches
--- `refs/heads/items/*` into the remote-tracking namespace.
local function remote_item_ref(remote: string, id: string,
    ended?: boolean): string
  return ("refs/remotes/%s/%s/%s"):format(remote,
    ended and "ended" or "items", id)
end

local function target_item_ref(id: string, ended?: boolean): string
  return (ended and "refs/heads/ended/" or "refs/heads/items/") .. id
end

--- Read the newest claim control commit from the item's first-parent history.
--- Ordinary holder mutations can sit above it without extending the lease.
local function read_state(root: string, tip: string,
    holder: string, product_base: string): claim.State | nil, string
  if (holder or "") == "" then return nil, "" end
  -- The subject is ours and deliberately carries the control kind. Using
  -- `%(trailers)` in a multi-column log format is unsafe: Git terminates each
  -- expanded trailer value with a newline. Read the one matching commit's body
  -- separately to recover its lineage instead.
  local r, err = child.run({"git", "log", "--first-parent", "--format=%H%x09%ct%x09%s",
      tip}, {cwd = root})
  if r == nil then return nil, err end
  if not r.ok then return nil, "git log failed: " .. r.stderr end
  for line in r.stdout:gmatch("([^\n]+)") do
    local sha, stamp, action, who =
    line:match("^(%x+)\t(%d+)\tclaim ([%a%-]+) %S+ by (%S+)$")
    if sha ~= nil and (action == "acquire" or action == "force"
      or action == "renew" or action == "drop") then
      if action == "drop" then return nil, "" end
      local when = math.tointeger(tonumber(stamp)) or 0
      local root_sha = sha
      if action == "renew" then
        local body = child.run({"git", "show", "-s", "--format=%B", sha}, {cwd = root})
        if body == nil or not body.ok then return nil, "could not read claim renewal" end
        root_sha = body.stdout:match("\nClaim%-Root: ([0-9a-f]+)\n") or ""
      end
      if root_sha == "" then
        return nil, "claim renewal has no Claim-Root trailer"
      end
      return {
        holder = who ~= "" and who or holder,
        root = root_sha,
        control = sha,
        acquired_at = when,
        renewed_at = when,
        expires_at = when + claim.LEASE_S,
        product_base = product_base or "",
      }, ""
    end
  end
  -- Compatibility for an old claim: its tip is its lease root and clock.
  local legacy = child.run({"git", "show", "-s", "--format=%ct", tip}, {cwd = root})
  if legacy == nil or not legacy.ok then
    return nil, "could not read legacy claim timestamp"
  end
  local when = math.tointeger(tonumber((legacy.stdout:gsub("%s+$", "")))) or 0
  return {holder = holder, root = tip, control = tip, acquired_at = when,
    renewed_at = when, expires_at = when + claim.LEASE_S,
    product_base = product_base or ""}, ""
end

local function message(action: string, id: string, caller: string,
    lineage: string, base: string, target: string, why: string): string
  local subject = ("claim %s %s by %s"):format(action, id:sub(1, 8), caller)
  local parts: {string} = {subject, "", "Claim-Caller: " .. caller}
  if lineage ~= "" then parts[#parts + 1] = "Claim-Root: " .. lineage end
  if base ~= "" then parts[#parts + 1] = "Claim-Base: " .. base end
  parts[#parts + 1] = "Claim-Target: " .. target
  if why ~= "" then parts[#parts + 1] = "Claim-Reason: " .. clean_line(why) end
  parts[#parts + 1] = "Op: claim-" .. action
  return table.concat(parts, "\n")
end

local function update_staging(root: string, ref: string, sha: string): boolean, string
  return refs.update_ref(root, ref, sha, refs.ZERO_SHA)
end

--- Reconstruct one claim publication plan solely from its reachable staging
--- commit.  Keeping retry data in Git means a later process needs no sqlite or
--- process-local receipt to render the exact same leased update.
local function prepared_from_entry(root: string, remote: string,
    entry: refs.RefEntry): Prepared | nil, string
  local id = entry.refname:match(
    "^refs/gitboard/prepared%-claims/[^/]+/([^/]+)$")
  if id == nil then return nil, "not a prepared claim ref" end
  local detail, derr = child.run({"git", "show", "-s",
      "--format=%P%x00%ct%x00%B", entry.sha}, {cwd = root})
  if detail == nil then return nil, derr end
  if not detail.ok then
    return nil, "could not read prepared claim: " .. detail.stderr
  end
  local parents, stamp, body = detail.stdout:match("^([^\0]*)\0([^\0]*)\0(.*)$")
  if parents == nil or parents == "" or parents:find(" ", 1, true) ~= nil then
    return nil, "prepared claim must have exactly one parent: " .. entry.refname
  end
  local action = body:match("^claim ([%a%-]+) ") or ""
  local lineage = body:match("\nClaim%-Root: ([0-9a-f]+)\n") or ""
  local claim_root = entry.sha
  if action == "renew" or action == "drop" then claim_root = lineage end
  if claim_root == "" then
    return nil, "prepared claim has no lineage: " .. entry.refname
  end
  local when = math.tointeger(tonumber(stamp)) or 0
  -- The item's namespace is history, not workflow state: modern completed
  -- items may still live under `items`, while imported ones live under
  -- `ended`. Keep the exact destination in the claim commit so Git-only
  -- retry never has to infer it from `resolution`.
  local target = body:match("\nClaim%-Target: (refs/heads/%S+)\n") or ""
  if target ~= target_item_ref(id) and target ~= target_item_ref(id, true) then
    return nil, "prepared claim has no valid Claim-Target trailer"
  end
  local remote_name = remote ~= "" and remote or "origin"
  return {
    id = id, status = "prepared", old_sha = parents, new_sha = entry.sha,
    staging_ref = entry.refname, target_ref = target, claim_root = claim_root,
    branch = claim.branch(id, claim_root), expires_at = when + claim.LEASE_S,
    push_argv = {"git", "push",
      ("--force-with-lease=%s:%s"):format(target, parents), remote_name,
      entry.refname .. ":" .. target},
  }, ""
end

--- Find an unexpired, semantically identical plan prepared by an earlier
--- invocation.  Retrying `claim` before publishing must render the same CAS,
--- not accumulate two staged successors that race each other.
local function prepared_retry(req: Request, tip: string): Prepared | nil, string
  local found, ferr = refs.for_each_ref_raw(req.root,
    {"refs/gitboard/prepared-claims"})
  if found == nil then return nil, ferr end
  for _, entry in ipairs(found) do
    if entry.refname:match("/" .. req.id .. "$") then
      local p, perr = prepared_from_entry(req.root, req.remote, entry)
      if p == nil then return nil, perr end
      if p.expires_at <= req.now then
        local cleaned, cerr = refs.update_ref(req.root, p.staging_ref,
          refs.ZERO_SHA, p.new_sha)
        if not cleaned then return nil, cerr end
      elseif p.old_sha == tip then
        local shown, serr = child.run(
          {"git", "show", "-s", "--format=%B", p.new_sha}, {cwd = req.root})
        if shown == nil then return nil, serr end
        if not shown.ok then return nil, "could not read prepared claim message" end
        local action, caller = shown.stdout:match(
          "^claim ([%a%-]+) %S+ by (%S+)")
        local compatible = (req.action == "take"
          and (action == "acquire" or action == "force"))
        or action == req.action
        if compatible and caller == req.caller then
          if req.action ~= "take"
          or shown.stdout:match("\nClaim%-Base: ([0-9a-f]+)\n")
          == req.product_base then
            return p, ""
          end
        end
      end
    end
  end
  return nil, ""
end

--- Prepare one independent claim CAS. It never changes source_ref/target_ref and
--- never invokes push. Concurrent batches remain partially successful because
--- each Prepared has its own lease and push instruction.
local function prepare(req: Request): Prepared | nil, string
  if req.now == nil or req.now <= 0 then return nil, "now must be an epoch second" end
  local current, current_err = format.require_current(req.root)
  if not current then return nil, current_err end
  if req.batch == "" or req.batch:find("..", 1, true) ~= nil
  or req.batch:find("/", 1, true) ~= nil then
    return nil, "batch must be one safe ref component"
  end
  -- `source_ref` is already the literal authoritative ref selected by the
  -- caller (a remote-tracking ref on a remote board).  The canonical board
  -- reader deliberately rewrites tracking names back to target names, which
  -- is useful to `store.list` but would make this exact comparison miss.
  local found, ferr = refs.for_each_ref_raw(req.root, {req.source_ref})
  if found == nil then return nil, ferr end
  local tip = ""
  for _, entry in ipairs(found) do
    if entry.refname == req.source_ref then tip = entry.sha end
  end
  if tip == "" then return nil, "no fetched item at " .. req.source_ref end
  local retry, rerr = prepared_retry(req, tip)
  if rerr ~= "" then return nil, rerr end
  if retry ~= nil then return retry, "" end
  local loaded, lerr = gitread.load(req.root, req.id, req.source_ref, tip)
  if loaded == nil then return nil, lerr end
  local it = loaded.it
  local st, serr = read_state(req.root, tip, it.claim or "", it.claim_base or "")
  if serr ~= "" then return nil, serr end

  local op = ""
  local lineage = ""
  local base = it.claim_base or ""
  if req.action == "take" then
    local refusal, owned = claim.take_refusal(st, req.caller, req.now,
      req.force or false, req.why or "")
    if refusal ~= nil then return nil, refusal end
    if owned then
      if st == nil then return nil, "owned claim has no state" end
      return {id = req.id, status = "already-owned", old_sha = tip,
        new_sha = tip, staging_ref = "", target_ref = req.target_ref,
        claim_root = st.root, branch = claim.branch(req.id, st.root),
        expires_at = st.expires_at, push_argv = {}}, ""
    end
    -- `claim_base` is the base of the WORK attempt, not of each lease
    -- holder. Once a handover exists, a reviewer acquisition inherits it;
    -- dropping the builder's lease never destroys the lineage evidence.
    local work_base = it.claim_base or ""
    if work_base == "" then work_base = req.product_base or "" end
    local badbase = sha_refusal(work_base, "product base")
    if badbase ~= nil then return nil, badbase end
    op = (st ~= nil and claim.status(st, req.now) == "active"
      and st.holder ~= req.caller) and "force" or "acquire"
    it.claim = req.caller
    it.claim_base = work_base
    base = work_base
  elseif req.action == "renew" then
    local refusal = claim.renew_refusal(st, req.caller, req.now)
    if refusal ~= nil then return nil, refusal end
    if st == nil then return nil, "active claim has no state" end
    op, lineage = "renew", st.root
  else
    local refusal = claim.drop_refusal(st, req.caller, req.now,
      req.force or false, req.why or "")
    if refusal ~= nil then return nil, refusal end
    if st == nil then return nil, "claim has no state" end
    op, lineage = "drop", st.root
    it.claim = ""
  end

  local spec = gitread.read_spec(req.root, {tip})
  local tree, terr = itemtree.build_tree(req.root, it, spec, true)
  if tree == nil then return nil, terr end
  local date = ("%d +0000"):format(req.now)
  local commit, cerr = gitobj.commit_tree(req.root, {
      tree = tree, parents = {tip},
      message = message(op, req.id, req.caller, lineage, base,
        req.target_ref, req.why or ""),
      author_name = req.caller, author_email = req.caller .. "@board",
      author_date = date, committer_name = "gitboard",
      committer_email = "gitboard@board", committer_date = date, op = "",
    })
  if commit == nil then return nil, cerr end
  local staging = ("refs/gitboard/prepared-claims/%s/%s"):format(req.batch, req.id)
  local staged, sterr = update_staging(req.root, staging, commit)
  if not staged then return nil, sterr end
  local root_sha = commit
  if op ~= "acquire" and op ~= "force" then
    if st == nil then return nil, "claim control has no prior state" end
    root_sha = st.root
  end
  local remote = req.remote ~= "" and req.remote or "origin"
  local argv = {"git", "push",
    ("--force-with-lease=%s:%s"):format(req.target_ref, tip), remote,
    staging .. ":" .. req.target_ref}
  return {id = req.id, status = "prepared", old_sha = tip, new_sha = commit,
    staging_ref = staging, target_ref = req.target_ref, claim_root = root_sha,
    branch = claim.branch(req.id, root_sha), expires_at = req.now + claim.LEASE_S,
    push_argv = argv}, ""
end

--- Best-effort batch preparation. One refusal never rolls back or suppresses
--- another item, and all requests should carry the same `now` for one deadline.
local function prepare_batch(requests: {Request}): BatchResult
  local out: BatchResult = {prepared = {}, already_owned = {}, refused = {}}
  for _, req in ipairs(requests) do
    local p, err = prepare(req)
    if p == nil then out.refused[req.id] = err
    elseif p.status == "already-owned" then out.already_owned[#out.already_owned + 1] = p
    else out.prepared[#out.prepared + 1] = p end
  end
  return out
end

--- Rediscover prepared claim operations after the preparing process exits.
--- The expected-old SHA is the staged commit's sole parent; the destination
--- follows the item-ref convention. This keeps publish/refresh callers out of
--- the private staging-ref grammar and makes retry state entirely Git-native.
local function list_prepared(root: string, remote: string): {Prepared} | nil, string
  local found, ferr = refs.for_each_ref_raw(root,
    {"refs/gitboard/prepared-claims"})
  if found == nil then return nil, ferr end
  local out: {Prepared} = {}
  for _, entry in ipairs(found) do
    if entry.refname:match(
      "^refs/gitboard/prepared%-claims/[^/]+/[^/]+$") then
      local p, perr = prepared_from_entry(root, remote, entry)
      if p == nil then return nil, perr end
      out[#out + 1] = p
    end
  end
  return out, ""
end

--- After the caller pushes and fetches, confirm that canonical observed state
--- equals the prepared commit and remove only the disposable staging ref.
local function confirm(root: string, source_ref: string,
    prepared: Prepared): boolean, string
  local found, err = refs.for_each_ref_raw(root, {source_ref})
  if found == nil then return false, err end
  for _, entry in ipairs(found) do
    if entry.refname == source_ref and entry.sha == prepared.new_sha then
      local r, derr = child.run({"git", "update-ref", "-d", prepared.staging_ref,
          prepared.new_sha}, {cwd = root})
      if r == nil then return false, derr end
      if not r.ok then return false, "could not clean staging ref: " .. r.stderr end
      return true, ""
    end
  end
  return false, "fetched ref does not match prepared claim"
end

local record gitclaim
  type Action = Action
  type Request = Request
  type Prepared = Prepared
  type BatchResult = BatchResult
  remote_item_ref: function(remote: string, id: string,
  ended?: boolean): string
  target_item_ref: function(id: string, ended?: boolean): string
  read_state: function(root: string, tip: string, holder: string,
  product_base: string): claim.State | nil, string
  prepare: function(req: Request): Prepared | nil, string
  prepare_batch: function(requests: {Request}): BatchResult
  list_prepared: function(root: string, remote: string): {Prepared} | nil, string
  confirm: function(root: string, source_ref: string,
  prepared: Prepared): boolean, string
end

local M: gitclaim = {
  remote_item_ref = remote_item_ref,
  target_item_ref = target_item_ref,
  read_state = read_state,
  prepare = prepare,
  prepare_batch = prepare_batch,
  list_prepared = list_prepared,
  confirm = confirm,
}
return M
