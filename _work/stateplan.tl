--- One frozen chain, N tree/commit pairs, one non-forced publication.
local tx = require("_work.statetransaction")
local projection = require("_work.stateplan_git")
local git = require("_work.singlehead_git")
local literal = require("_work.singlehead_literal")
local objects = require("_work.singlehead_objects")
local calls = require("_work.singlehead_calls")
local receipts = require("_work.stateplan_receipts")
local hash = require("cosmic.hash")
local codec = require("cosmic.codec")
local saved = require("_work.stateplan_file")
local type Gate = function(string, string, tx.Transition): boolean, string
local record Plan
  format: string
  frozen: tx.Frozen
  expected_head: string
  expected_commit: string
  base_tree: string
  candidate: string
  publish_by: integer
  calls: {calls.Call}
  snapshots: {{{string: any}}}
end
local function fence(root: string, head: string, transition: tx.Transition, gate?: Gate): boolean, string
  for _, dependency in ipairs(transition.dependencies) do
    local actual, err = projection.path_id(root, head, dependency.path)
    if actual == nil then return false, err end
    if actual ~= dependency.id then return false, "LOST_RACE: " .. dependency.path end
  end
  if head ~= transition.base and transition.bounded then
    if gate == nil then return false, "bounded transition requires gate revalidation" end
    return gate(root, head, transition)
  end
  return true, ""
end
local function render(plan: Plan): {calls.Call} | nil, string
  local out: {calls.Call} = {}
  local parent, base = plan.expected_head, plan.base_tree
  for index, transition in ipairs(plan.frozen.transitions) do
    local group = literal.sequence() as {{string: any}} -- cast: explicit empty connector sequence
    local size = 0
    local function flush()
      local id = "tree_" .. tostring(index) .. "_" .. tostring(#out + 1)
      out[#out + 1] = {id = id, tool = "github_create_tree", guard = nil, arguments = {
          repository_full_name = plan.frozen.repository, base_tree_sha = base ~= "" and base or nil, tree_elements = group}}
      base = "$" .. id .. ".sha"
      group = literal.sequence() as {{string: any}} -- cast: explicit empty connector sequence
      size = 0
    end
    local entries = literal.sequence() as {{string: any}} -- cast: explicit empty connector sequence
    local deletes = false
    for _, change in ipairs(transition.changes) do if change.delete then deletes = true end end
    if deletes then
      base = ""
      entries = plan.snapshots[index]
    else
      for _, change in ipairs(transition.changes) do
        entries[#entries + 1] = {path = change.path, mode = change.mode, type = "blob", content = change.content}
      end
    end
    for _, entry in ipairs(entries) do
      local encoded, err = literal.encode(entry)
      if encoded == nil then return nil, err end
      if #encoded > calls.TREE_CALL_BYTES then return nil, "one tree entry exceeds connector budget" end
      if #group > 0 and size + #encoded > calls.TREE_CALL_BYTES then flush() end
      group[#group + 1] = {path = entry.path, mode = entry.mode, type = entry["type"], content = entry.content, sha = entry.sha}
      size = size + #encoded
    end
    flush()
    local id = "commit_" .. tostring(index)
    out[#out + 1] = {id = id, tool = "github_create_commit", guard = nil, arguments = {
        repository_full_name = plan.frozen.repository, parent_sha = parent, tree_sha = base,
        message = transition.message}}
    parent = "$" .. id .. ".sha"
  end
  out[#out + 1] = {id = "publish", tool = "github_update_ref", guard = {publish_by = plan.publish_by,
      rule = "if nonzero, current time must be strictly before deadline"}, arguments = {
      repository_full_name = plan.frozen.repository, branch_name = plan.frozen.branch, sha = parent, force = false}}
  return out, ""
end
local function validate(plan: Plan): boolean, string
  if plan.format ~= "gitboard-state-plan-v1" then return false, "unsupported state plan" end
  local ok, err = tx.validate(plan.frozen)
  if not ok then return false, err end
  if not objects.checked_sha(plan.expected_head, false) or not objects.checked_sha(plan.base_tree, false)
  or not objects.checked_sha(plan.candidate, false) then return false, "invalid plan base" end
  local deadline = 0
  for _, transition in ipairs(plan.frozen.transitions) do
    if transition.publish_by > 0 and (deadline == 0 or transition.publish_by < deadline) then
      deadline = transition.publish_by
    end
  end
  local commit_id = codec.encode_hex(hash.digest("sha1", "commit " .. tostring(#plan.expected_commit) .. "\0" .. plan.expected_commit))
  if commit_id ~= plan.expected_head or plan.expected_commit:match("^tree ([0-9a-f]+)\n") ~= plan.base_tree then
    return false, "plan base tree differs from exact expected commit"
  end
  if deadline ~= plan.publish_by then return false, "invalid plan deadline" end
  local expected, rerr = render(plan)
  if expected == nil then return false, rerr end
  if literal.encode(expected) ~= literal.encode(plan.calls) then return false, "saved publication chain differs" end
  return true, ""
end
local function build(root: string, frozen: tx.Frozen, head: string, gate?: Gate, now?: integer): Plan | nil, string
  local copy, err = tx.freeze(frozen)
  if copy == nil then return nil, err end
  local base, berr = git.oid(root, head .. "^{tree}")
  if base == nil then return nil, berr end
  local expected_commit, eerr = git.run(root, {"cat-file", "commit", head})
  if expected_commit == nil then return nil, eerr end
  local parent, deadline = head, 0
  local snapshots: {{{string: any}}} = {}
  for _, transition in ipairs(copy.transitions) do
    local ok, ferr = fence(root, parent, transition, gate)
    if not ok then return nil, ferr end
    if transition.publish_by > 0 and (deadline == 0 or transition.publish_by < deadline) then
      deadline = transition.publish_by
    end
    if deadline > 0 and (now or os.time()) >= deadline then return nil, "prepared claim expired" end
    local tree, terr = projection.apply(root, parent, transition.changes)
    if tree == nil then return nil, terr end
    local candidate, cerr = projection.commit(root, parent, tree, transition)
    if candidate == nil then return nil, cerr end
    local listing, lerr = git.run(root, {"ls-tree", "-r", "-z", candidate})
    if listing == nil then return nil, lerr end
    local entries = literal.sequence() as {{string: any}} -- cast: explicit empty connector sequence
    for mode, sha, path in listing:gmatch("(%d+) blob ([0-9a-f]+)\t([^%z]+)%z") do
      local entry: {string: any} = {path = path, mode = mode, type = "blob", sha = sha}
      for _, change in ipairs(transition.changes) do
        if change.path == path and not change.delete then entry.sha = nil; entry.content = change.content end
      end
      entries[#entries + 1] = entry
    end
    snapshots[#snapshots + 1] = entries
    parent = candidate
  end
  local complete, cerr = receipts.complete_chain(root, parent, copy)
  if not complete then return nil, cerr end
  local plan: Plan = {format = "gitboard-state-plan-v1", frozen = copy, expected_head = head, expected_commit = expected_commit,
    base_tree = base, candidate = parent, publish_by = deadline, calls = {}, snapshots = snapshots}
  local rendered, rerr = render(plan)
  if rendered == nil then return nil, rerr end
  plan.calls = rendered
  return plan, ""
end
local function connector_calls(plan: Plan, repository?: string, branch?: string): {calls.Call} | nil, string
  local ok, err = validate(plan)
  if not ok then return nil, err end
  if (repository ~= nil and repository ~= plan.frozen.repository)
  or (branch ~= nil and branch ~= plan.frozen.branch) then return nil, "plan destination differs" end
  return render(plan)
end
local function connector_call(plan: Plan, index: integer, now?: integer): calls.Call | nil, string
  local chain, err = connector_calls(plan)
  if chain == nil then return nil, err end
  if index < 1 or index > #chain then return nil, "call index outside plan" end
  if index == #chain and plan.publish_by > 0 and (now or os.time()) >= plan.publish_by then
    return nil, "prepared claim expired before publication"
  end
  local call = chain[index]
  call.guard = nil
  return call, ""
end
local function validate_local(root: string, plan: Plan): boolean, string
  local ok, err = validate(plan)
  if not ok then return false, err end
  local complete, cerr = receipts.complete_chain(root, plan.candidate, plan.frozen)
  if not complete then return false, cerr end
  local base, berr = git.oid(root, plan.candidate .. "~" .. tostring(#plan.frozen.transitions))
  if base == nil then return false, berr end
  if base ~= plan.expected_head then return false, "candidate chain has different base" end
  for index, transition in ipairs(plan.frozen.transitions) do
    local tip, terr = git.oid(root, plan.candidate .. "~" .. tostring(#plan.frozen.transitions - index))
    if tip == nil then return false, terr end
    local listing, lerr = git.run(root, {"ls-tree", "-r", "-z", tip})
    if listing == nil then return false, lerr end
    local entries = literal.sequence() as {{string: any}} -- cast: explicit empty connector sequence
    for mode, sha, path in listing:gmatch("(%d+) blob ([0-9a-f]+)\t([^%z]+)%z") do
      local entry: {string: any} = {path = path, mode = mode, type = "blob", sha = sha}
      for _, change in ipairs(transition.changes) do
        if change.path == path and not change.delete then entry.sha = nil; entry.content = change.content end
      end
      entries[#entries + 1] = entry
    end
    if literal.encode(entries) ~= literal.encode(plan.snapshots[index]) then return false, "saved snapshot differs from candidate tree" end
  end
  return true, ""
end
local function local_candidate(root: string, plan: Plan, now?: integer): string | nil, string
  local ok, err = validate_local(root, plan)
  if not ok then return nil, err end
  if plan.publish_by > 0 and (now or os.time()) >= plan.publish_by then return nil, "prepared claim expired before publication" end
  return plan.candidate, ""
end
local function save(path: string, plan: Plan): boolean, string
  local ok, err = validate(plan)
  if not ok then return false, err end
  local payload, perr = literal.encode(plan)
  if payload == nil then return false, perr end
  local raw, rerr = literal.encode({plan = plan, sha256 = objects.sha256(payload)})
  if raw == nil then return false, rerr end
  return saved.write_once(path, raw)
end
local function load_saved(path: string): Plan | nil, string
  local fs = require("cosmic.fs")
  local raw, err = fs.read(path)
  if raw == nil then return nil, err end
  local decoded, derr = literal.decode_object(raw)
  if decoded == nil then return nil, derr end
  local value, sha = decoded.plan, decoded.sha256
  if not (value is {string: any}) or not (sha is string) then return nil, "malformed sealed state plan" end
  local payload, perr = literal.encode(value)
  if payload == nil then return nil, perr end
  if objects.sha256(payload) ~= sha then return nil, "state plan integrity check failed" end
  local plan = value as Plan -- cast: protected validation of untrusted literal
  local ran, ok, verr = pcall(validate, plan)
  if not ran or not ok then return nil, ran and verr or "malformed state plan" end
  if literal.encode(decoded) ~= raw then return nil, "state plan is not canonical" end
  return plan, ""
end
local record Module
  type Plan = Plan
  type Gate = Gate
  fence: function(root: string, head: string, transition: tx.Transition, gate?: Gate): boolean, string
  build: function(root: string, frozen: tx.Frozen, head: string, gate?: Gate, now?: integer): Plan | nil, string
  validate: function(Plan): boolean, string
  validate_local: function(string, Plan): boolean, string
  connector_calls: function(plan: Plan, repository?: string, branch?: string): {calls.Call} | nil, string
  connector_call: function(plan: Plan, index: integer, now?: integer): calls.Call | nil, string
  local_candidate: function(root: string, plan: Plan, now?: integer): string | nil, string
  save: function(string, Plan): boolean, string
  load: function(string): Plan | nil, string
end
local M: Module = {fence = fence, build = build, validate = validate, validate_local = validate_local, connector_calls = connector_calls,
  connector_call = connector_call, local_candidate = local_candidate, save = save, load = load_saved}
return M
