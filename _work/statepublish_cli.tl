--- Snapshot publication CLI and the compact JSON protocol used by Work.
local fs = require("cosmic.fs")
local json = require("cosmic.json")
local gate = require("_work.gitgate")
local protocol = require("_work.snapshot_protocol")
local recovery = require("_work.snapshot_recovery")
local snapshot_publish = require("_work.snapshot_publish")
local store = require("_work.store")
local workspace = require("_work.snapshot_workspace")

local function emit(value: any): integer
  local raw, err = json.encode(value)
  if raw == nil then return gate.verdict_line("publish", false, err) end
  print(raw)
  return 0
end

local function array(values: {any}): {any}
  return json.array(values)
end

local function protocol_action(s: store.Store, commit: string, remote: string,
    action: string, returned_tree: string, candidate_sha: string,
    observed_head: string, recovery_override: string, now?: integer): integer
  local path = recovery_override ~= "" and recovery_override or workspace.recovery_path(s.root)
  if action == "reconcile" then
    local outcome, oerr = snapshot_publish.reconcile_saved(s.root, commit,
      remote, path, observed_head)
    if outcome == nil then return gate.verdict_line("publish", false, oerr) end
    return emit(outcome)
  elseif action == "update" then
    local call, cerr = snapshot_publish.update_call(s.root, commit, remote,
      path, observed_head, now)
    if call == nil then return gate.verdict_line("publish", false, cerr) end
    return emit(call)
  end
  local planned, err: snapshot_publish.Planned | nil, string
  if fs.is_present(path) or fs.is_present(path .. ".candidate")
  or fs.is_present(path .. ".updating") then
    planned, err = snapshot_publish.resume_plan(s.root, commit, remote)
  else
    planned, err = snapshot_publish.plan(s.root, commit, remote, now)
  end
  if planned == nil then return gate.verdict_line("publish", false, err) end
  local plan, report = planned.plan, planned.report
  if action == "begin" then
    local state: recovery.Recovery
    if fs.is_present(path) then
      local loaded, lerr = recovery.load(path)
      if loaded == nil then return gate.verdict_line("publish", false, lerr) end
      local bound, berr = recovery.binding(loaded, plan)
      if not bound then return gate.verdict_line("publish", false, berr) end
      state = loaded
    else
      local begun, berr = recovery.begin(path, plan)
      if begun == nil then return gate.verdict_line("publish", false, berr) end
      state = begun
    end
    return emit({status = state.phase, candidate = state.remote_sha,
        commit = plan.local_commit, parent = plan.parent,
        tree = plan.tree, publish_by = plan.publish_by,
        repository = plan.destination.repository, branch = plan.destination.branch,
        remote = plan.destination.remote,
        changed = array(report.changed as {any}), -- cast: JSON value array
        new_issues = array(report.new_issues as {any}), -- cast: JSON value array
        existing_issues = array(report.existing_issues as {any})}) -- cast: JSON value array
  elseif action == "trees" then
    local calls, cerr = protocol.tree_calls(plan)
    if calls == nil then return gate.verdict_line("publish", false, cerr) end
    return emit({calls = array(calls as {any})}) -- cast: JSON value array
  elseif action == "commit" then
    local call, cerr = protocol.commit_call(plan, returned_tree)
    if call == nil then return gate.verdict_line("publish", false, cerr) end
    return emit(call)
  elseif action == "candidate" then
    local state, cerr = recovery.record_candidate(path, plan, candidate_sha)
    if state == nil then return gate.verdict_line("publish", false, cerr) end
    return emit({status = state.phase, candidate = state.remote_sha})
  end
  return gate.verdict_line("publish", false,
    "protocol action must be begin, trees, commit, candidate, update, or reconcile")
end

local function cmd_publish(s: store.Store, selectors: {string}, remote: string,
    _execute: boolean, ...: any): integer
  local options = {...}
  local plan_path, from_plan, call_index = options[1], options[2], options[3]
  local published_sha = options[4]
  if (from_plan or "") ~= "" or (call_index or "") ~= ""
  or (published_sha or "") ~= "" or (plan_path or "") ~= "" then
    return gate.verdict_line("publish", false,
      "REFUSED: format-6 saved transaction plans are obsolete and are not snapshot plans")
  end
  local commit = selectors[1] or ""
  if commit == "" then
    local candidate, err = workspace.read(s.root)
    if candidate == nil then return gate.verdict_line("publish", false,
        err ~= "" and err or "name the snapshot COMMIT") end
    commit = candidate.commit
  end
  if #selectors > 1 or #commit ~= 40 or not commit:match("^[0-9a-f]+$") then
    return gate.verdict_line("publish", false,
      "REFUSED: publish takes one full snapshot COMMIT; transaction and draft selectors are obsolete")
  end
  local ok, detail = snapshot_publish.execute(s.root, commit, remote, nil)
  return gate.verdict_line("publish", ok, detail)
end

local record Module
  cmd_publish: function(store.Store, {string}, string, boolean, ...: any): integer
  protocol: function(store.Store, string, string, string, string, string,
  string, string, integer | nil): integer
end
local M: Module = {cmd_publish = cmd_publish, protocol = protocol_action}
return M
