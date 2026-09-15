--- Connector calls for one ordinary snapshot publication.
local call_codec = require("_work.stateplan_calls")
local recovery = require("_work.snapshot_recovery")
local snapshot = require("_work.snapshot")

local type Call = call_codec.Call

local function update_refusal(plan: snapshot.Plan, observed_head: string,
    now?: integer): string
  if observed_head ~= plan.parent then
    return "canonical head advanced; snapshot conflicts"
  end
  if plan.publish_by > 0 and (now or os.time()) >= plan.publish_by then
    return "prepared claim expired before publication"
  end
  return ""
end

local function tree_calls(plan: snapshot.Plan): {Call} | nil, string
  local ok, err = snapshot.validate(plan)
  if not ok then return nil, err end
  local out: {Call} = {}
  local base = plan.complete_tree and "" or plan.base_tree
  local _tree, terr = call_codec.append_tree_calls(out, "tree_", plan.destination.repository,
    base, plan.entries)
  if _tree == nil then return nil, terr end
  return out, ""
end

--- The returned tree must be the already validated local final tree.
local function commit_call(plan: snapshot.Plan, returned_tree: string): Call | nil, string
  local ok, err = snapshot.validate(plan)
  if not ok then return nil, err end
  if returned_tree ~= plan.tree then return nil, "connector returned a different snapshot tree" end
  return {id = "commit", tool = "github_create_commit", guard = nil,
    arguments = {repository_full_name = plan.destination.repository,
      parent_sha = plan.parent, tree_sha = returned_tree, message = plan.message}}, ""
end

local function checked_update(plan: snapshot.Plan, state: recovery.Recovery,
    observed_head: string, now?: integer): Call | nil, string
  local bound, err = recovery.binding(state, plan)
  if not bound then return nil, err end
  if state.phase ~= "updating" then return nil, "snapshot update was not durably armed" end
  local refusal = update_refusal(plan, observed_head, now)
  if refusal ~= "" then return nil, refusal end
  return {id = "publish", tool = "github_update_ref", guard = nil,
    arguments = {repository_full_name = plan.destination.repository,
      branch_name = plan.destination.branch, sha = state.remote_sha, force = false}}, ""
end

--- Persist uncertainty before returning the only call that can move the ref.
local function arm_update(path: string, plan: snapshot.Plan,
    candidate: recovery.Recovery, observed_head: string,
    now?: integer): Call | nil, string
  local bound, err = recovery.binding(candidate, plan)
  if not bound then return nil, err end
  if candidate.phase ~= "candidate" then return nil, "snapshot recovery is not a candidate" end
  local refusal = update_refusal(plan, observed_head, now)
  if refusal ~= "" then return nil, refusal end
  local armed, aerr = recovery.mark_updating(path, plan, candidate)
  if armed == nil then return nil, aerr end
  return checked_update(plan, armed, observed_head, now)
end

local record Module
  type Call = Call
  tree_calls: function(snapshot.Plan): {Call} | nil, string
  commit_call: function(snapshot.Plan, string): Call | nil, string
  arm_update: function(string, snapshot.Plan, recovery.Recovery, string,
  integer | nil): Call | nil, string
  checked_update: function(snapshot.Plan, recovery.Recovery, string,
  integer | nil): Call | nil, string
end

local M: Module = {tree_calls = tree_calls, commit_call = commit_call,
  arm_update = arm_update, checked_update = checked_update}
return M
