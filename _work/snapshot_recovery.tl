--- Compact transient recovery for one snapshot publication.
---
--- The base record freezes composition before any connector call.  Candidate
--- and updating records are create-once sidecars, so each later phase is
--- durable before the action it authorizes.  A lost object-creation response
--- leaves `prepared` and is safe to recreate; `updating` must reconcile first.
local fs = require("cosmic.fs")
local objects = require("_work.stateplan_objects")
local saved = require("_work.stateplan_file")
local snapshot = require("_work.snapshot")
local git = require("_work.singlehead_git")

local FORMAT < const > = "gitboard-snapshot-recovery-v1"

local record Recovery
  format: string
  phase: string
  local_commit: string
  repository: string
  branch: string
  remote: string
  target_url: string
  remote_sha: string
end

local record Status
  status: string
  candidate: string
  reason: string
end

local function for_plan(plan: snapshot.Plan, phase: string, remote_sha: string): Recovery
  return {format = FORMAT, phase = phase, local_commit = plan.local_commit,
    repository = plan.destination.repository, branch = plan.destination.branch,
    remote = plan.destination.remote, target_url = plan.destination.target_url,
    remote_sha = remote_sha}
end

local function validate(value: Recovery): boolean, string
  if value.format ~= FORMAT
  or (value.phase ~= "prepared" and value.phase ~= "candidate"
    and value.phase ~= "updating")
  or not objects.checked_sha(value.local_commit, false)
  or objects.checked_repository(value.repository) ~= value.repository
  or objects.checked_branch(value.branch) ~= value.branch
  or value.remote == "" or value.remote:find("[%s%z]")
  or value.target_url == "" or value.target_url:find("[%z\r\n]") then
    return false, "invalid snapshot recovery record"
  end
  if value.phase == "prepared" then
    if value.remote_sha ~= "" then return false, "prepared recovery has a remote SHA" end
  elseif not objects.checked_sha(value.remote_sha, false) then
    return false, "candidate recovery lacks a remote SHA"
  end
  return true, ""
end

local function binding(value: Recovery, plan: snapshot.Plan): boolean, string
  local ok, err = validate(value)
  if not ok then return false, err end
  if value.local_commit ~= plan.local_commit
  or value.repository ~= plan.destination.repository
  or value.branch ~= plan.destination.branch
  or value.remote ~= plan.destination.remote
  or value.target_url ~= plan.destination.target_url then
    return false, "snapshot recovery destination or local commit differs"
  end
  return true, ""
end

local function begin(path: string, plan: snapshot.Plan): Recovery | nil, string
  local ok, err = snapshot.validate(plan)
  if not ok then return nil, err end
  local value = for_plan(plan, "prepared", "")
  local written, werr = saved.save_value(path, value)
  if not written then return nil, werr end
  return value, ""
end

local function decode_file(path: string): Recovery | nil, string
  local raw, err = saved.load_value(path)
  if raw == nil then return nil, err end
  local value = raw as Recovery -- cast: protected untrusted literal shape
  local ran, ok, verr = pcall(validate, value)
  if not ran or not ok then return nil, ran and verr or "malformed snapshot recovery" end
  return value, ""
end

local function same_attempt(a: Recovery, b: Recovery): boolean
  return a.local_commit == b.local_commit and a.repository == b.repository
  and a.branch == b.branch and a.remote == b.remote
  and a.target_url == b.target_url
end

local function load_recovery(path: string): Recovery | nil, string
  local prepared, err = decode_file(path)
  if prepared == nil then return nil, err end
  if prepared.phase ~= "prepared" then return nil, "snapshot recovery base is not prepared" end
  local current = prepared
  if fs.is_present(path .. ".candidate") then
    local candidate, cerr = decode_file(path .. ".candidate")
    if candidate == nil then return nil, cerr end
    if candidate.phase ~= "candidate" or not same_attempt(prepared, candidate) then
      return nil, "snapshot candidate recovery does not continue prepared attempt"
    end
    current = candidate
  end
  if fs.is_present(path .. ".updating") then
    local updating, uerr = decode_file(path .. ".updating")
    if updating == nil then return nil, uerr end
    if current.phase ~= "candidate" or updating.phase ~= "updating"
    or not same_attempt(current, updating)
    or current.remote_sha ~= updating.remote_sha then
      return nil, "snapshot updating recovery does not continue candidate attempt"
    end
    current = updating
  end
  return current, ""
end

--- Persist a provider-returned SHA before an update-ref can be armed.
local function record_candidate(path: string, plan: snapshot.Plan,
    remote_sha: string): Recovery | nil, string
  local prepared, err = decode_file(path)
  if prepared == nil then return nil, err end
  local bound, berr = binding(prepared, plan)
  if not bound or prepared.phase ~= "prepared" then
    return nil, berr ~= "" and berr or "snapshot recovery was not prepared"
  end
  if not objects.checked_sha(remote_sha, false) then return nil, "invalid returned remote SHA" end
  local value = for_plan(plan, "candidate", remote_sha)
  local written, werr = saved.save_value(path .. ".candidate", value)
  if not written then return nil, werr end
  return value, ""
end

--- Durable point immediately before the caller invokes update_ref.
local function mark_updating(path: string, plan: snapshot.Plan,
    candidate: Recovery): Recovery | nil, string
  local bound, err = binding(candidate, plan)
  if not bound then return nil, err end
  if candidate.phase ~= "candidate" then return nil, "snapshot recovery is not a candidate" end
  if fs.is_present(path .. ".updating") then
    return nil, "snapshot update is already uncertain; reconcile before retry"
  end
  local value = for_plan(plan, "updating", candidate.remote_sha)
  local written, werr = saved.save_value(path .. ".updating", value)
  if not written then return nil, werr end
  return value, ""
end

local function same_author(a: snapshot.Author, b: snapshot.Author): boolean
  return a.name == b.name and a.email == b.email and a.date == b.date
end

local function first_parent_segment(root: string, head: string,
    base: string, candidate: string): boolean, boolean, string
  local raw, err = git.run(root, {"rev-list", "--first-parent", "--parents", head})
  if raw == nil then return false, false, err end
  local contains, reached = false, false
  for line in raw:gmatch("([^\n]+)") do
    local sha = line:match("^([0-9a-f]+)")
    if sha == candidate then contains = true end
    if sha == base then reached = true; break end
  end
  return contains, reached, ""
end

local function exact_identity(root: string, candidate: string,
    plan: snapshot.Plan): boolean
  local identity = snapshot.commit_identity(root, candidate)
  return identity ~= nil and identity.parent == plan.parent
  and identity.tree == plan.tree and identity.message == plan.message
  and same_author(identity.author, plan.author)
end

--- Recover a cleaned confirmed attempt from fetched canonical history.  This
--- closes the response-loss window after confirmation cleanup without keeping
--- a permanent receipt: the exact public commit is its own durable proof.
local function discover(root: string, head: string,
    plan: snapshot.Plan): Status | nil, string
  local valid, verr = snapshot.validate(plan)
  if not valid then return nil, verr end
  if head == plan.parent then return {status = "uncertain", candidate = "",
      reason = "publication is not yet visible"}, "" end
  local raw, err = git.run(root,
    {"rev-list", "--first-parent", "--parents", head})
  if raw == nil then return nil, err end
  for line in raw:gmatch("([^\n]+)") do
    local sha, parent = line:match("^([0-9a-f]+)%s+([0-9a-f]+)")
    if parent == plan.parent then
      if exact_identity(root, sha, plan) then
        return {status = "confirmed", candidate = sha, reason = ""}, ""
      end
      return {status = "conflict", candidate = "",
        reason = "canonical head advanced without this snapshot on its first-parent chain"}, ""
    end
  end
  return {status = "uncertain", candidate = "",
    reason = "fetched first-parent history does not reach snapshot parent"}, ""
end

--- Classify only from a fetched canonical head and exact publication proof.
local function reconcile(root: string, head: string, plan: snapshot.Plan,
    recovery: Recovery): Status | nil, string
  local valid, verr = snapshot.validate(plan)
  if not valid then return nil, verr end
  local bound, berr = binding(recovery, plan)
  if not bound then return nil, berr end
  if recovery.phase == "prepared" then
    return {status = "uncertain", candidate = "",
      reason = "no returned remote SHA; connector object creation may be repeated"}, ""
  end
  if head == plan.parent then return {status = "uncertain", candidate = recovery.remote_sha,
      reason = "publication is not yet visible; retry only this saved ref update"}, "" end
  local on_chain, base_reached, cerr = first_parent_segment(root, head,
    plan.parent, recovery.remote_sha)
  if cerr ~= "" then return nil, cerr end
  if not on_chain and not base_reached then return {status = "uncertain", candidate = recovery.remote_sha,
      reason = "fetched first-parent history does not reach snapshot parent"}, "" end
  if not on_chain then return {status = "conflict", candidate = recovery.remote_sha,
      reason = "canonical head advanced without this snapshot on its first-parent chain"}, "" end
  local identity, ierr = snapshot.commit_identity(root, recovery.remote_sha)
  if identity == nil then
    return {status = "conflict", candidate = recovery.remote_sha, reason = ierr}, ""
  end
  if identity.parent ~= plan.parent then return {status = "conflict", candidate = recovery.remote_sha,
      reason = "published snapshot has different parent"}, "" end
  if identity.tree ~= plan.tree then return {status = "conflict", candidate = recovery.remote_sha,
      reason = "published snapshot has different tree"}, "" end
  if identity.message ~= plan.message then return {status = "conflict", candidate = recovery.remote_sha,
      reason = "published snapshot has different message"}, "" end
  if not same_author(identity.author, plan.author) then return {status = "conflict", candidate = recovery.remote_sha,
      reason = "published snapshot has different logical author"}, "" end
  return {status = "confirmed", candidate = recovery.remote_sha, reason = ""}, ""
end

local function clear(path: string): boolean, string
  for _, suffix in ipairs({".updating", ".candidate", ""}) do
    local file = path .. suffix
    if fs.is_present(file) then
      local ok, err = fs.remove(file)
      if not ok then return false, err end
    end
  end
  return true, ""
end

local record Module
  type Recovery = Recovery
  type Status = Status
  FORMAT: string
  validate: function(Recovery): boolean, string
  binding: function(Recovery, snapshot.Plan): boolean, string
  begin: function(string, snapshot.Plan): Recovery | nil, string
  load: function(string): Recovery | nil, string
  record_candidate: function(string, snapshot.Plan, string): Recovery | nil, string
  mark_updating: function(string, snapshot.Plan, Recovery): Recovery | nil, string
  reconcile: function(string, string, snapshot.Plan, Recovery): Status | nil, string
  discover: function(string, string, snapshot.Plan): Status | nil, string
  clear: function(string): boolean, string
end

local M: Module = {FORMAT = FORMAT, validate = validate, binding = binding,
  begin = begin, load = load_recovery, record_candidate = record_candidate,
  mark_updating = mark_updating, reconcile = reconcile, discover = discover,
  clear = clear}
return M
