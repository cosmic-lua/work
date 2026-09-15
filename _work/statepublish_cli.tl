--- Snapshot publication CLI and the compact JSON protocol used by Work.
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

local function begin_value(planned: snapshot_publish.Planned,
    status: string, candidate: string, reason?: string): {string: any}
  local plan = planned.plan
  return {status = status, candidate = candidate, reason = reason or "",
    commit = plan.local_commit, parent = plan.parent, tree = plan.tree,
    publish_by = plan.publish_by, repository = plan.destination.repository,
    branch = plan.destination.branch, remote = plan.destination.remote,
    changed = array(planned.report.changed as {any}), -- cast: JSON value array
    new_issues = array(planned.report.new_issues as {any}), -- cast: JSON value array
    existing_issues = array(planned.report.existing_issues as {any})} -- cast: JSON value array
end

local function begin_outcome(err: string): string | nil, string
  local status, reason = err:match("^([a-z]+):%s*(.*)")
  if status == "uncertain" or status == "conflict" then
    return status, reason
  end
  return nil, ""
end

local function protocol_action(s: store.Store, commit: string, remote: string,
    action: string, returned_tree: string, candidate_sha: string,
    observed_head: string, now?: integer): integer
  local path = workspace.recovery_path(s.root)
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
  if recovery.present(path) then
    planned, err = snapshot_publish.resume_plan(s.root, commit, remote)
  elseif action == "begin" then
    planned, err = snapshot_publish.begin_plan(s.root, commit, remote, now)
  else
    planned, err = snapshot_publish.plan(s.root, commit, remote, now)
  end
  if planned == nil then return gate.verdict_line("publish", false, err) end
  local plan = planned.plan
  if action == "begin" then
    local status, reason = begin_outcome(err)
    if status ~= nil then
      return emit(begin_value(planned, status, "", reason))
    end
    local state, berr = snapshot_publish.start(s.root, plan)
    if state == nil then
      status, reason = begin_outcome(berr)
      if status ~= nil then
        return emit(begin_value(planned, status, "", reason))
      end
      return gate.verdict_line("publish", false, berr)
    end
    return emit(begin_value(planned, state.phase, state.remote_sha))
  elseif action == "trees" then
    local calls, cerr = protocol.tree_calls(plan)
    if calls == nil then return gate.verdict_line("publish", false, cerr) end
    return emit({calls = array(calls as {any})}) -- cast: JSON value array
  elseif action == "commit" then
    local call, cerr = protocol.commit_call(plan, returned_tree)
    if call == nil then return gate.verdict_line("publish", false, cerr) end
    return emit(call)
  elseif action == "candidate" then
    local state, cerr = snapshot_publish.record_candidate(s.root, plan, candidate_sha)
    if state == nil then return gate.verdict_line("publish", false, cerr) end
    return emit({status = state.phase, candidate = state.remote_sha})
  end
  return gate.verdict_line("publish", false,
    "protocol action must be begin, trees, commit, candidate, update, or reconcile")
end

local function cmd_publish(s: store.Store, selectors: {string}, remote: string): integer
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
  cmd_publish: function(store.Store, {string}, string): integer
  protocol: function(store.Store, string, string, string, string, string,
  string, integer | nil): integer
end
local M: Module = {cmd_publish = cmd_publish, protocol = protocol_action}
return M
