--- Three-call connector protocol for one ordinary snapshot publication.
--- Work invokes the calls; this module validates and orders their arguments.
local call_codec = require("_work.stateplan_calls")
local recovery = require("_work.snapshot_recovery")
local snapshot = require("_work.snapshot")

local type Call = call_codec.Call

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

local function creation_calls(plan: snapshot.Plan): {Call} | nil, string
  local out, err = tree_calls(plan)
  if out == nil then return nil, err end
  local tree = "$" .. out[#out].id .. ".sha"
  out[#out + 1] = {id = "commit", tool = "github_create_commit", guard = nil,
    arguments = {repository_full_name = plan.destination.repository,
      parent_sha = plan.parent, tree_sha = tree, message = plan.message}}
  return out, ""
end

--- Reviewable full protocol.  The symbolic SHA marks the required handoff:
--- persist the create_commit result through recovery before update_ref.
local function calls(plan: snapshot.Plan): {Call} | nil, string
  local out, err = creation_calls(plan)
  if out == nil then return nil, err end
  out[#out + 1] = {id = "publish", tool = "github_update_ref",
    guard = {publish_by = plan.publish_by, expected_head = plan.parent,
      rule = "persist commit SHA, fetch canonical head, require exact parent and live deadline"},
    arguments = {repository_full_name = plan.destination.repository,
      branch_name = plan.destination.branch, sha = "$commit.sha", force = false}}
  return out, ""
end

local function checked_update(plan: snapshot.Plan, state: recovery.Recovery,
    observed_head: string, now?: integer): Call | nil, string
  local bound, err = recovery.binding(state, plan)
  if not bound then return nil, err end
  if state.phase ~= "updating" then return nil, "snapshot update was not durably armed" end
  if observed_head ~= plan.parent then return nil, "canonical head advanced; snapshot conflicts" end
  if plan.publish_by > 0 and (now or os.time()) >= plan.publish_by then
    return nil, "prepared claim expired before publication"
  end
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
  if observed_head ~= plan.parent then return nil, "canonical head advanced; snapshot conflicts" end
  if plan.publish_by > 0 and (now or os.time()) >= plan.publish_by then
    return nil, "prepared claim expired before publication"
  end
  local armed, aerr = recovery.mark_updating(path, plan, candidate)
  if armed == nil then return nil, aerr end
  return checked_update(plan, armed, observed_head, now)
end

--- Shell transport uses the exact local object under the same whole-head gate.
local function shell_candidate(root: string, plan: snapshot.Plan,
    observed_head: string, now?: integer): string | nil, string
  local ok, err = snapshot.validate_local(root, plan)
  if not ok then return nil, err end
  if observed_head ~= plan.parent then return nil, "canonical head advanced; snapshot conflicts" end
  if plan.publish_by > 0 and (now or os.time()) >= plan.publish_by then
    return nil, "prepared claim expired before publication"
  end
  return plan.local_commit, ""
end

local record Module
  type Call = Call
  tree_calls: function(snapshot.Plan): {Call} | nil, string
  commit_call: function(snapshot.Plan, string): Call | nil, string
  creation_calls: function(snapshot.Plan): {Call} | nil, string
  calls: function(snapshot.Plan): {Call} | nil, string
  arm_update: function(string, snapshot.Plan, recovery.Recovery, string,
  integer | nil): Call | nil, string
  checked_update: function(snapshot.Plan, recovery.Recovery, string,
  integer | nil): Call | nil, string
  shell_candidate: function(string, snapshot.Plan, string,
  integer | nil): string | nil, string
end

local M: Module = {tree_calls = tree_calls, commit_call = commit_call,
  creation_calls = creation_calls, calls = calls,
  arm_update = arm_update, checked_update = checked_update,
  shell_candidate = shell_candidate}
return M
