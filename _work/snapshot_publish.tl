--- Shell publication and refresh for one validated final-board snapshot.
local fs = require("cosmic.fs")
local cache = require("_work.cache")
local prepared = require("_work.prepared")
local refs = require("_work.refs")
local snapshot = require("_work.snapshot")
local protocol = require("_work.snapshot_protocol")
local recovery = require("_work.snapshot_recovery")
local staging = require("_work.statestaging")
local stateclaim = require("_work.stateclaim")
local store = require("_work.store")
local validate = require("_work.snapshot_validate")
local workspace = require("_work.snapshot_workspace")

local record Planned
  plan: snapshot.Plan
  report: validate.Report
end

local function publication_branch(root: string): string
  local ok, out, _err = require("_work.singlehead_git").probe(root,
    {"config", "--get", "gitboard.publicationBranch"})
  if ok then local branch = out:gsub("%s+$", ""); return branch end
  return "state"
end

local function destination(root: string, remote: string): snapshot.Destination
  local url = staging.target_url(root, remote)
  if url == "" then url = "local://" .. root end
  return {repository = staging.repository(root, remote),
    branch = publication_branch(root),
    remote = remote, target_url = url}
end

local function plan(root: string, commit: string, remote: string,
    now?: integer): Planned | nil, string
  local identity, ierr = snapshot.commit_identity(root, commit)
  if identity == nil then return nil, ierr end
  local report, rerr = validate.preflight(root, identity.parent, commit, now)
  if report == nil then return nil, rerr end
  local captured, cerr = snapshot.capture_validated(root, commit,
    destination(root, remote), report.publish_by)
  if captured == nil then return nil, cerr end
  return {plan = captured, report = report}, ""
end

local function fetch_argv(remote: string): {string}
  return {"git", "fetch", "--atomic", remote,
    "+refs/heads/state:refs/remotes/" .. remote .. "/state",
    "+refs/heads/board/format:refs/remotes/" .. remote .. "/board/format"}
end

local function fetch_branch_argv(remote: string, branch: string,
    endpoint?: string): {string}
  return {"git", "fetch", "--atomic", endpoint or remote,
    "+refs/heads/" .. branch .. ":refs/remotes/" .. remote .. "/state",
    "+refs/heads/board/format:refs/remotes/" .. remote .. "/board/format"}
end

local function compact(report: validate.Report): string
  local rows: {string} = {}
  for _, changed in ipairs(report.changed) do
    rows[#rows + 1] = changed.id:sub(1, 8) .. "=" .. changed.status
  end
  local out = "changed=" .. (#rows > 0 and table.concat(rows, ",") or "0")
  if #report.new_issues > 0 then out = out .. " new-spec-issues=" .. tostring(#report.new_issues) end
  if #report.existing_issues > 0 then out = out .. " existing-spec-issues=" .. tostring(#report.existing_issues) end
  return out
end

local function current(root: string, remote: string): string | nil, string
  local ref = refs.board_mode(root) == "local" and "refs/heads/state"
  or "refs/remotes/" .. remote .. "/state"
  return refs.read_ref(root, ref)
end

local function finish_at(root: string, frozen: snapshot.Plan,
    state: recovery.Recovery, head: string, path: string): boolean, string
  local outcome, oerr = recovery.reconcile(root, head, frozen, state)
  if outcome == nil then return false, oerr end
  if outcome.status ~= "confirmed" then return false, outcome.status .. ": " .. outcome.reason end
  local candidate = workspace.read(root)
  if candidate ~= nil and candidate.commit == frozen.local_commit then
    local cleared, cerr = workspace.clear(root, candidate.commit)
    if not cleared then return false, "confirmed, but local snapshot ref remains: " .. cerr end
  end
  local removed, rerr = recovery.clear(path)
  if not removed then return false, "confirmed, but recovery record remains: " .. rerr end
  refs.clear_overlay(root)
  return true, "confirmed " .. outcome.candidate
end

local function finish(root: string, frozen: snapshot.Plan,
    state: recovery.Recovery): boolean, string
  local head, herr = current(root, frozen.destination.remote)
  if head == nil then return false, herr end
  return finish_at(root, frozen, state, head, workspace.recovery_path(root))
end

local function historical_plan(root: string, commit: string,
    remote: string): Planned | nil, string
  local identity, ierr = snapshot.commit_identity(root, commit)
  if identity == nil then return nil, ierr end
  local authored = math.tointeger(tonumber(identity.author.date:match("^(%-?%d+)")))
  if authored == nil then return nil, "snapshot author date is invalid" end
  return plan(root, commit, remote, authored)
end

local function reconcile_saved(root: string, commit: string, remote: string,
    path: string, head: string): recovery.Status | nil, string
  local state, lerr = recovery.load(path)
  if state == nil then return nil, lerr end
  local planned, perr = historical_plan(root, commit, remote)
  if planned == nil then return nil, perr end
  local frozen = planned.plan
  local outcome, oerr = recovery.reconcile(root, head, frozen, state)
  if outcome == nil then return nil, oerr end
  if outcome.status == "confirmed" then
    local ok, ferr = finish_at(root, frozen, state, head, path)
    if not ok then return nil, ferr end
  end
  return outcome, ""
end

local function update_call(root: string, commit: string, remote: string,
    path: string, head: string, now?: integer): protocol.Call | nil, string
  local planned, perr = plan(root, commit, remote, now)
  if planned == nil then return nil, perr end
  local frozen = planned.plan
  local state, lerr = recovery.load(path)
  if state == nil then return nil, lerr end
  if state.phase == "candidate" then
    return protocol.arm_update(path, frozen, state, head, now)
  elseif state.phase == "updating" then
    return protocol.checked_update(frozen, state, head, now)
  end
  return nil, "snapshot has no durable candidate to update"
end

local function observe_remote(root: string, endpoint: string, branch: string): string | nil, string
  local out, err = require("_work.singlehead_git").text(root,
    {"ls-remote", "--refs", endpoint, "refs/heads/" .. branch})
  if out == nil then return nil, err end
  local sha = out:match("^([0-9a-f]+)%s")
  if sha == nil then return nil, "remote state head is missing" end
  return sha, ""
end

local function execute(root: string, commit: string, remote: string,
    now?: integer): boolean, string
  local path = workspace.recovery_path(root)
  local state: recovery.Recovery = nil
  local frozen: snapshot.Plan = nil
  local report: validate.Report = nil
  local err = ""
  local retry_update = false
  if fs.is_present(path) then
    local loaded, lerr = recovery.load(path)
    if loaded == nil then return false, lerr end
    local identity, ierr = snapshot.commit_identity(root, commit)
    if identity == nil then return false, ierr end
    local authored = math.tointeger(tonumber(identity.author.date:match("^(%-?%d+)")))
    if authored == nil then return false, "snapshot author date is invalid" end
    local planned, perr = plan(root, commit, remote, authored)
    if planned == nil then return false, perr end
    frozen, report = planned.plan, planned.report
    local bound, berr = recovery.binding(loaded, frozen)
    if not bound then return false, berr end
    state = loaded
    if state.phase == "updating" then
      if refs.board_mode(root) == "remote" then
        local fetched, ferr = prepared.execute(root,
          fetch_branch_argv(remote, frozen.destination.branch,
            frozen.destination.target_url))
        if not fetched then return false, "uncertain: " .. ferr end
      end
      local head, herr = current(root, remote)
      if head == nil then return false, herr end
      local outcome, oerr = recovery.reconcile(root, head, frozen, state)
      if outcome == nil then return false, oerr end
      if outcome.status == "confirmed" then return finish(root, frozen, state) end
      if outcome.status == "conflict" then return false, "conflict: " .. outcome.reason end
      if head ~= frozen.parent then return false, "uncertain: " .. outcome.reason end
      retry_update = true
    end
  else
    local planned, perr = plan(root, commit, remote, now)
    if planned == nil then return false, perr end
    frozen, report = planned.plan, planned.report
    local retained, rerr = workspace.retain(root, commit)
    if not retained then return false, rerr end
    state, err = recovery.begin(path, frozen)
    if state == nil then return false, err end
  end
  -- Current authority/deadline is rechecked for a first update or a retry. The
  -- historical validation above existed only to prove an already-landed SHA.
  local planned, perr = plan(root, commit, remote, now)
  if planned == nil then return false, perr end
  frozen, report = planned.plan, planned.report
  if state.phase == "prepared" then
    state, err = recovery.record_candidate(path, frozen, frozen.local_commit)
    if state == nil then return false, err end
  end
  local observed: string | nil
  if retry_update or refs.board_mode(root) == "local" then observed, err = current(root, remote)
  else observed, err = observe_remote(root, frozen.destination.target_url,
      frozen.destination.branch) end
  if observed == nil then return false, err end
  local _call: protocol.Call | nil = nil
  local aerr = ""
  if retry_update then _call, aerr = protocol.checked_update(frozen, state, observed, now)
  else _call, aerr = protocol.arm_update(path, frozen, state, observed, now) end
  if _call == nil then return false, aerr end
  local moved, merr: boolean, string
  if refs.board_mode(root) == "local" then
    moved, merr = refs.update_ref(root, "refs/heads/state", frozen.local_commit, frozen.parent)
  else
    moved, merr = prepared.execute(root,
      {"git", "push", remote, frozen.local_commit .. ":refs/heads/" .. frozen.destination.branch})
  end
  if refs.board_mode(root) == "remote" then
    local fetched, ferr = prepared.execute(root,
      fetch_branch_argv(remote, frozen.destination.branch,
        frozen.destination.target_url))
    if not fetched then return false, "uncertain: " .. ferr end
  end
  local loaded, lerr = recovery.load(path)
  if loaded == nil then return false, lerr end
  local confirmed, detail = finish(root, frozen, loaded)
  if confirmed then return true, detail .. " " .. compact(report) end
  if not moved then return false, detail .. (merr ~= "" and ": " .. merr or "") end
  return false, detail
end

local function publish(s: store.Store, execute_now?: boolean): boolean, string
  local candidate, err = workspace.read(s.root)
  if candidate == nil then return err == "" and true or false, err end
  if refs.board_mode(s.root) == "local" or execute_now then
    local ok, detail = execute(s.root, candidate.commit, refs.board_remote(s.root))
    if ok then
      local head = current(s.root, refs.board_remote(s.root))
      if head ~= nil then
        s.state_head = head
        cache.after_fetch(s.root, head)
      end
      s.state_receipt = ""
    end
    return ok, detail
  end
  local planned, perr = plan(s.root, candidate.commit,
    refs.board_remote(s.root))
  if planned == nil then return false, perr end
  local head, herr = current(s.root, refs.board_remote(s.root))
  if head == nil then return false, herr end
  s.state_head, s.state_receipt = head, ""
  s.state_paths, s.state_reads = {}, {}
  s.leased_item, s.leased_sha, s.leased_ref, s.touched_at = {}, {}, {}, {}
  s.native_view, s.native_history, s.native_history_head = nil, nil, ""
  s.board_digest, s.fresh_lease = "", ""
  refs.clear_overlay(s.root)
  local _closed, _cerr = store.close(s)
  return true, "prepared " .. candidate.commit .. " " .. compact(planned.report)
  .. "\npublish: gitboard publish " .. candidate.commit
end

local function sync(s: store.Store, execute_fetch?: boolean): boolean, string
  local remote = refs.board_remote(s.root)
  if execute_fetch and refs.board_mode(s.root) == "remote" then
    local ok, err = prepared.execute(s.root,
      fetch_branch_argv(remote, publication_branch(s.root),
        staging.target_url(s.root, remote)))
    if not ok then return false, err end
  end
  local head, herr = current(s.root, remote)
  if head == nil then return false, herr end
  local authority, aerr = stateclaim.authority(s.root, head)
  if authority == nil then return false, aerr end
  s.state_head, s.state_receipt = head, ""
  s.state_paths, s.state_reads = {}, {}
  s.leased_item, s.leased_sha, s.leased_ref, s.touched_at = {}, {}, {}, {}
  s.native_view, s.native_history, s.native_history_head = nil, nil, ""
  s.board_digest, s.fresh_lease = "", ""
  refs.clear_overlay(s.root)
  local _closed, _cerr = store.close(s)
  cache.after_fetch(s.root, head)
  return true, "head=" .. head:sub(1, 12) .. "\n" .. authority
end

local record Module
  type Planned = Planned
  destination: function(string, string): snapshot.Destination
  plan: function(string, string, string, integer | nil): Planned | nil, string
  resume_plan: function(string, string, string): Planned | nil, string
  fetch_argv: function(string): {string}
  fetch_branch_argv: function(string, string, string | nil): {string}
  execute: function(string, string, string, integer | nil): boolean, string
  publish: function(store.Store, boolean | nil): boolean, string
  sync: function(store.Store, boolean | nil): boolean, string
  compact: function(validate.Report): string
  update_call: function(string, string, string, string, string,
  integer | nil): protocol.Call | nil, string
  reconcile_saved: function(string, string, string, string,
  string): recovery.Status | nil, string
end
local M: Module = {destination = destination, plan = plan,
  resume_plan = historical_plan, fetch_argv = fetch_argv,
  fetch_branch_argv = fetch_branch_argv,
  execute = execute, publish = publish, sync = sync, compact = compact,
  update_call = update_call, reconcile_saved = reconcile_saved}
return M
