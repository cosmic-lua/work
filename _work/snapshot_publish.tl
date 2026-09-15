local cache = require("_work.cache")
local prepared = require("_work.prepared")
local refs = require("_work.refs")
local snapshot = require("_work.snapshot")
local snapshot_lock = require("_work.snapshot_lock")
local protocol = require("_work.snapshot_protocol")
local recovery = require("_work.snapshot_recovery")
local staging = require("_work.statestaging")
local stateclaim = require("_work.stateclaim")
local store = require("_work.store")
local validate = require("_work.snapshot_validate")
local workspace = require("_work.snapshot_workspace")
local record Planned plan: snapshot.Plan report: validate.Report end
local function publication_branch(root: string): string
  local ok, out, _err = require("_work.singlehead_git").probe(root,
    {"config", "--get", "gitboard.publicationBranch"})
  if ok then local branch = out:gsub("%s+$", ""); return branch end
  return "state"
end
local function destination(root: string, remote: string): snapshot.Destination
  if refs.board_mode(root) == "local" then
    local common = snapshot_lock.common_dir(root)
    return {repository = staging.repository(root, remote), branch = "state", remote = remote,
      target_url = "local://" .. (common or root)}
  end
  local url = staging.target_url(root, remote)
  return {repository = staging.repository(root, remote),
    branch = publication_branch(root),
    remote = remote, target_url = url}
end
local function same_destination(a: snapshot.Destination, b: snapshot.Destination): boolean
  return a.repository == b.repository and a.branch == b.branch
  and a.remote == b.remote and a.target_url == b.target_url
end
local function plan_at(root: string, commit: string, target: snapshot.Destination,
    now?: integer): Planned | nil, string
  local identity, ierr = snapshot.commit_identity(root, commit)
  if identity == nil then return nil, ierr end
  local report, rerr = validate.preflight(root, identity.parent, commit, now)
  if report == nil then return nil, rerr end
  local captured, cerr = snapshot.capture_validated(root, commit, target,
    report.publish_by, report.identity, report.changes)
  if captured == nil then return nil, cerr end
  return {plan = captured, report = report}, ""
end
local function plan(root: string, commit: string, remote: string,
    now?: integer): Planned | nil, string
  return plan_at(root, commit, destination(root, remote), now)
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
local function discovery_head(root: string, frozen: snapshot.Plan): string | nil, string
  if refs.board_mode(root) == "remote" then
    local fetched, ferr = prepared.execute(root,
      fetch_branch_argv(frozen.destination.remote, frozen.destination.branch,
        frozen.destination.target_url))
    if not fetched then return nil, ferr end
  end
  return workspace.canonical_head(root, frozen.destination.remote)
end
local function start(root: string, frozen: snapshot.Plan): recovery.Recovery | nil, string
  local head, cerr = discovery_head(root, frozen)
  if head == nil then return nil,
    "uncertain: cannot inspect exact publication destination: " .. cerr end
  local discovered: recovery.Status = nil
  if head ~= frozen.parent then
    local outcome, oerr = recovery.discover(root, head, frozen)
    if outcome == nil then return nil, oerr end
    discovered = outcome
  end
  local held, herr = snapshot_lock.acquire(root)
  if held == nil then return nil, herr end
  local _guard < close > = held
  if not same_destination(destination(root, frozen.destination.remote),
    frozen.destination) then
    return nil, "snapshot publication destination changed while starting"
  end
  local path = workspace.recovery_path(root)
  if recovery.present(path) then
    local state, lerr = recovery.load(path)
    if state == nil then return nil, lerr end
    local bound, berr = recovery.binding(state, frozen)
    if not bound then return nil, berr end
    local retained, rerr = workspace.retain(root, frozen.local_commit)
    if not retained then return nil, rerr end
    return state, ""
  end
  local retained, rerr = workspace.retain(root, frozen.local_commit)
  if not retained then return nil, rerr end
  local candidate = workspace.read(root)
  if candidate == nil or candidate.commit ~= frozen.local_commit then
    return nil, "snapshot proposal changed before publication could freeze it"
  end
  local current, cherr = workspace.canonical_head(root, frozen.destination.remote)
  if current == nil then return nil, cherr end
  if current ~= head then
    local outcome, oerr = recovery.discover(root, current, frozen)
    if outcome == nil then return nil, oerr end
    discovered = outcome
  end
  if discovered ~= nil and discovered.status ~= "confirmed" then
    return nil, discovered.status .. ": " .. discovered.reason
  end
  local state, berr = recovery.begin(path, frozen)
  if state == nil then return nil, berr end
  if discovered ~= nil then
    return recovery.record_candidate(path, frozen, discovered.candidate)
  end
  return state, ""
end
local function record_candidate(root: string, frozen: snapshot.Plan,
    remote_sha: string): recovery.Recovery | nil, string
  local held, herr = snapshot_lock.acquire(root)
  if held == nil then return nil, herr end
  local _guard < close > = held
  local path = workspace.recovery_path(root)
  local state, lerr = recovery.load(path)
  if state == nil then return nil, lerr end
  local bound, berr = recovery.binding(state, frozen)
  if not bound then return nil, berr end
  if state.phase ~= "prepared" then
    return nil, "snapshot recovery already has a durable candidate"
  end
  return recovery.record_candidate(path, frozen, remote_sha)
end
local function finish_at(root: string, frozen: snapshot.Plan,
    head: string, path: string): boolean, string
  local held, herr = snapshot_lock.acquire(root)
  if held == nil then return false, herr end
  local _guard < close > = held
  local current_state, lerr = recovery.load(path)
  if current_state == nil then return false, lerr end
  local bound, berr = recovery.binding(current_state, frozen)
  if not bound then return false, berr end
  local outcome, oerr = recovery.reconcile(root, head, frozen, current_state)
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
local function finish(root: string, frozen: snapshot.Plan): boolean, string
  local head, herr = workspace.canonical_head(root, frozen.destination.remote)
  if head == nil then return false, herr end
  return finish_at(root, frozen, head, workspace.recovery_path(root))
end
local function historical_plan(root: string, commit: string,
    remote: string): Planned | nil, string
  local identity, ierr = snapshot.commit_identity(root, commit)
  if identity == nil then return nil, ierr end
  local authored, aerr = snapshot.author_time(identity.author)
  if authored == nil then return nil, aerr end
  return plan(root, commit, remote, authored)
end
local function historical_plan_at(root: string, commit: string,
    target: snapshot.Destination): Planned | nil, string
  local identity, ierr = snapshot.commit_identity(root, commit)
  if identity == nil then return nil, ierr end
  local authored, aerr = snapshot.author_time(identity.author)
  if authored == nil then return nil, aerr end
  return plan_at(root, commit, target, authored)
end
local function begin_plan(root: string, commit: string, remote: string,
    now?: integer): Planned | nil, string
  local planned, err = plan(root, commit, remote, now)
  if planned ~= nil then return planned, "" end
  local historical, herr = historical_plan(root, commit, remote)
  if historical == nil then return nil, err ~= "" and err or herr end
  local head, cerr = discovery_head(root, historical.plan)
  if head == nil then return historical,
    "uncertain: cannot inspect exact publication destination: " .. cerr end
  local outcome, oerr = recovery.discover(root, head, historical.plan)
  if outcome ~= nil and outcome.status == "confirmed" then return historical, "" end
  if outcome ~= nil and outcome.status == "conflict" then
    return historical, "conflict: " .. outcome.reason
  end
  if outcome ~= nil then return historical, "uncertain: " .. outcome.reason end
  return historical, "uncertain: " .. oerr
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
    local ok, ferr = finish_at(root, frozen, head, path)
    if not ok then return nil, ferr end
  end
  return outcome, ""
end
local function update_call(root: string, commit: string, remote: string,
    path: string, head: string, now?: integer): protocol.Call | nil, string
  local held, herr = snapshot_lock.acquire(root)
  if held == nil then return nil, herr end
  local _guard < close > = held
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
  if recovery.present(path) then
    local loaded, lerr = recovery.load(path)
    if loaded == nil then return false, lerr end
    local identity, ierr = snapshot.commit_identity(root, commit)
    if identity == nil then return false, ierr end
    local authored, aerr = snapshot.author_time(identity.author)
    if authored == nil then return false, aerr end
    local planned, perr = plan(root, commit, remote, authored)
    if planned == nil then return false, perr end
    frozen, report = planned.plan, planned.report
    local bound, berr = recovery.binding(loaded, frozen)
    if not bound then return false, berr end
    state = loaded
  else
    local planned, perr = begin_plan(root, commit, remote, now)
    if planned == nil then return false, perr end
    if perr ~= "" then return false, perr end
    frozen, report = planned.plan, planned.report
    state, err = start(root, frozen)
    if state == nil then return false, err end
  end
  if state.phase == "candidate" or state.phase == "updating" then
    if refs.board_mode(root) == "remote" then
      local fetched, ferr = prepared.execute(root,
        fetch_branch_argv(remote, frozen.destination.branch,
          frozen.destination.target_url))
      if not fetched then return false, "uncertain: " .. ferr end
    end
    local head, herr = workspace.canonical_head(root, remote)
    if head == nil then return false, herr end
    local outcome, oerr = recovery.reconcile(root, head, frozen, state)
    if outcome == nil then return false, oerr end
    if outcome.status == "confirmed" then return finish(root, frozen) end
    if outcome.status == "conflict" then return false, "conflict: " .. outcome.reason end
    if head ~= frozen.parent then return false, "uncertain: " .. outcome.reason end
  end
  if state.phase == "prepared" then
    state, err = record_candidate(root, frozen, frozen.local_commit)
    if state == nil then return false, err end
  end
  local observed: string | nil
  if state.phase == "updating" or refs.board_mode(root) == "local" then
    observed, err = workspace.canonical_head(root, remote)
  else observed, err = observe_remote(root, frozen.destination.target_url,
      frozen.destination.branch) end
  if observed == nil then return false, err end
  local update_sha = ""
  local held, lockerr = snapshot_lock.acquire(root)
  if held == nil then return false, lockerr end
  do
    local _guard < close > = held
    if not same_destination(destination(root, remote), frozen.destination) then
      return false, "snapshot publication destination changed before update"
    end
    local loaded, lerr = recovery.load(path)
    if loaded == nil then return false, lerr end
    local bound, berr = recovery.binding(loaded, frozen)
    if not bound then return false, berr end
    local deadline, derr = validate.recheck(report, frozen.author.name,
      frozen.message, now)
    if deadline == nil then return false, derr end
    frozen.publish_by = deadline
    if loaded.remote_sha ~= frozen.local_commit
    and not snapshot.object_present(root, loaded.remote_sha) then
      return false, "saved provider candidate is unavailable locally; resume with "
      .. "gitboard publish " .. commit .. " --protocol update"
    end
    local exact, xerr = snapshot.identity_matches(root, loaded.remote_sha, frozen)
    if not exact then return false, xerr end
    update_sha = loaded.remote_sha
    local call, aerr: protocol.Call | nil, string
    if loaded.phase == "candidate" then
      call, aerr = protocol.arm_update(path, frozen, loaded, observed, now)
    elseif loaded.phase == "updating" then
      call, aerr = protocol.checked_update(frozen, loaded, observed, now)
    else return false, "snapshot has no durable candidate to update" end
    if call == nil then return false, aerr end
  end
  local moved, merr: boolean, string
  if refs.board_mode(root) == "local" then
    moved, merr = refs.update_ref(root, "refs/heads/state", update_sha, frozen.parent)
  else
    local stale: boolean
    moved, stale, merr = refs.push_atomic(root,
      {{ref = "refs/heads/" .. frozen.destination.branch,
          old = frozen.parent, source = update_sha}},
      frozen.destination.target_url)
    if stale and merr ~= "" then merr = "stale lease: " .. merr end
  end
  if refs.board_mode(root) == "remote" then
    local fetched, ferr = prepared.execute(root,
      fetch_branch_argv(remote, frozen.destination.branch,
        frozen.destination.target_url))
    if not fetched then return false, "uncertain: " .. ferr end
  end
  local confirmed, detail = finish(root, frozen)
  if confirmed then return true, detail .. " " .. compact(report) end
  if not moved then return false, detail .. (merr ~= "" and ": " .. merr or "") end
  return false, detail
end
local function abandon(root: string, commit: string): boolean, string
  local path = workspace.recovery_path(root)
  local state: recovery.Recovery = nil
  local planned: Planned = nil
  local saved_local, orphaned = false, false
  if recovery.present(path) then
    local loaded, lerr = recovery.load(path)
    if loaded == nil then return false, "cannot abandon malformed recovery: " .. lerr end
    if loaded.local_commit ~= commit then return false,
      "--abandon must name the frozen full snapshot commit" end
    state = loaded
    orphaned = not recovery.base_present(path)
    local target: snapshot.Destination = {repository = state.repository,
      branch = state.branch, remote = state.remote, target_url = state.target_url}
    saved_local = state.target_url:find("local://", 1, true) == 1
    if saved_local ~= (refs.board_mode(root) == "local") then return false,
      "snapshot publication mode differs from frozen destination" end
    planned, lerr = historical_plan_at(root, commit, target)
    if planned == nil then return false, lerr end
    if (state.phase == "updating" or orphaned) and not saved_local then
      local fetched, ferr = prepared.execute(root,
        fetch_branch_argv(state.remote, state.branch, state.target_url))
      if not fetched then return false, "uncertain: " .. ferr end
    end
  end
  local held, herr = snapshot_lock.acquire(root)
  if held == nil then return false, herr end
  local _guard < close > = held
  if recovery.present(path) ~= (state ~= nil) then return false,
    "snapshot recovery changed; retry --abandon for fresh reconciliation" end
  if state ~= nil and saved_local ~= (refs.board_mode(root) == "local") then
    return false, "snapshot publication mode changed during abandonment" end
  if state ~= nil and orphaned == recovery.base_present(path) then
    return false, "snapshot recovery changed; retry --abandon for fresh reconciliation"
  end
  local candidate, cerr = workspace.read(root)
  if state == nil then
    if candidate == nil then return false, cerr ~= "" and cerr or "no local snapshot" end
    if candidate.commit ~= commit then
      return false, "--abandon must name the current full snapshot commit"
    end
  else
    local current, lerr = recovery.load(path)
    if current == nil then return false, lerr end
    local bound, berr = recovery.binding(current, planned.plan)
    if not bound then return false, berr end
    if current.phase == "updating" and state.phase ~= "updating" then
      return false, "snapshot update became uncertain; retry --abandon to fetch its exact destination"
    end
    state = current
    if state.phase == "updating" or orphaned then
      local head, headerr = workspace.canonical_head(root, state.remote)
      if head == nil then return false, headerr end
      local outcome, oerr = recovery.reconcile(root, head, planned.plan, state)
      if outcome == nil then return false, oerr end
      if outcome.status ~= "conflict" then return false, outcome.status
        .. ": reconcile or finish publication before abandoning" end
    end
    if candidate ~= nil and candidate.commit ~= commit then
      return false, "a different local snapshot proposal exists"
    end
  end
  local kept, kerr = workspace.retain_conflict(root,
    candidate or {commit = commit, parent = planned.plan.parent, claims_changed = false})
  if not kept then return false, kerr end
  if state ~= nil then
    local removed, rerr = recovery.clear(path)
    if not removed then return false, "snapshot retained, but recovery remains: " .. rerr end
  end
  return true, "abandoned snapshot retained at refs/gitboard/conflicts/" .. commit
end
local function reset_store(s: store.Store, head: string)
  s.state_head, s.state_receipt = head, ""
  s.state_paths, s.state_reads = {}, {}
  s.leased_item, s.leased_sha, s.leased_ref, s.touched_at = {}, {}, {}, {}
  s.native_view, s.native_history, s.native_history_head = nil, nil, ""
  s.board_digest, s.fresh_lease = "", ""
  refs.clear_overlay(s.root)
end
local function publish(s: store.Store, execute_now?: boolean): boolean, string
  local candidate, err = workspace.read(s.root)
  if candidate == nil then return err == "" and true or false, err end
  if refs.board_mode(s.root) == "local" or execute_now then
    local ok, detail = execute(s.root, candidate.commit, refs.board_remote(s.root))
    if ok then
      local head = workspace.canonical_head(s.root, refs.board_remote(s.root))
      if head ~= nil then s.state_head = head end
      reset_store(s, head or "")
      local _closed, _cerr = store.close(s)
      if head ~= nil then cache.after_fetch(s.root, head) end
    end
    return ok, detail
  end
  local planned, perr = plan(s.root, candidate.commit,
    refs.board_remote(s.root))
  if planned == nil then return false, perr end
  local head, herr = workspace.canonical_head(s.root, refs.board_remote(s.root))
  if head == nil then return false, herr end
  reset_store(s, head)
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
  local head, herr = workspace.canonical_head(s.root, remote)
  if head == nil then return false, herr end
  local authority, aerr = stateclaim.authority(s.root, head)
  if authority == nil then return false, aerr end
  reset_store(s, head)
  local _closed, _cerr = store.close(s)
  cache.after_fetch(s.root, head)
  return true, "head=" .. head:sub(1, 12) .. "\n" .. authority
end
local record Module
  type Planned = Planned
  destination: function(string, string): snapshot.Destination
  plan: function(string, string, string, integer | nil): Planned | nil, string
  begin_plan: function(string, string, string, integer | nil): Planned | nil, string
  resume_plan: function(string, string, string): Planned | nil, string
  fetch_argv: function(string): {string}
  fetch_branch_argv: function(string, string, string | nil): {string}
  execute: function(string, string, string, integer | nil): boolean, string
  start: function(string, snapshot.Plan): recovery.Recovery | nil, string
  record_candidate: function(string, snapshot.Plan, string): recovery.Recovery | nil, string
  abandon: function(string, string): boolean, string
  publish: function(s: store.Store, execute_now?: boolean): boolean, string
  sync: function(s: store.Store, execute_fetch?: boolean): boolean, string
  compact: function(validate.Report): string
  update_call: function(string, string, string, string, string,
  integer | nil): protocol.Call | nil, string
  reconcile_saved: function(string, string, string, string,
  string): recovery.Status | nil, string
end
local M: Module = {destination = destination, plan = plan,
  begin_plan = begin_plan, resume_plan = historical_plan, fetch_argv = fetch_argv,
  fetch_branch_argv = fetch_branch_argv,
  execute = execute, start = start, record_candidate = record_candidate,
  abandon = abandon, publish = publish, sync = sync, compact = compact,
  update_call = update_call, reconcile_saved = reconcile_saved}
return M
