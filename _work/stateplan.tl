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
local fs = require("cosmic.fs")
local record Guard
  publish_by: integer
  expected_head: string
  rule: string
end
local record Call
  id: string
  tool: string
  arguments: {string: any}
  guard: Guard | nil
end
local type Gate = function(string, string, tx.Transition): boolean, string
local record Plan
  format: string
  frozen: tx.Frozen
  expected_head: string
  expected_commit: string
  base_tree: string
  candidate: string
  publish_by: integer
  calls: {Call}
  snapshots: {{{string: any}}}
end
--- The write fence at publication, in the order the design fixes: every path
--- this transition RECORDED must hold the same object id at `head` as it did at
--- the staging base — any difference is `LOST_RACE` and comes first, which a
--- bounded transition never skips — and only then, when the head has moved, is a
--- bounded transition's own gate re-run against it.
--- @param root string The repository holding `head`
--- @param head string The fetched head this transition would land on
--- @param transition tx.Transition The frozen transition
--- @param gate Gate | nil The bounded revalidation; required when bounded
--- @return boolean True when the transition may be rebased onto `head`
--- @return string "LOST_RACE: <path>", or the gate's own refusal
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
--- The connector calls one plan is published by, rendered from the SAVED
--- attempt and nothing else: per transition a `create_tree` split at the
--- connector's byte budget and a `create_commit` parented on the previous one,
--- then a single non-forced `update_ref` carrying the deadline guard. A
--- transition with a deletion is rendered as a complete tree from its recorded
--- snapshot instead, since the wire has no way to say "remove this path".
--- @param plan Plan The saved attempt
--- @return {Call} | nil The ordered calls, the last one the publication point
--- @return string Error message
local function render(plan: Plan): {Call} | nil, string
  local out: {Call} = {}
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
  out[#out + 1] = {id = "publish", tool = "github_update_ref", guard = {publish_by = plan.publish_by, expected_head = plan.expected_head,
      rule = "remote head must equal expected_head; if nonzero, current time must be strictly before deadline"}, arguments = {
      repository_full_name = plan.frozen.repository, branch_name = plan.frozen.branch, sha = parent, force = false}}
  return out, ""
end
--- Everything about a saved attempt that must still hold before any call is
--- made from it: its own version, the frozen chain's rules, the exact expected
--- commit it was built against (re-hashed, so a plan cannot claim a base it did
--- not read), the earliest member deadline, and calls that are byte-identical to
--- what `render` produces from the same plan — a plan whose calls were edited is
--- refused rather than executed.
--- @param plan Plan The saved attempt
--- @return boolean True when the attempt may still be published
--- @return string Error message
local function validate(plan: Plan): boolean, string
  if plan.format ~= "gitboard-state-plan-v2" then
    return false, "unsupported state plan; regenerate a new attempt from its frozen transaction"
  end
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
--- Freeze one publishable attempt against `head`: each transition fenced and
--- rebased onto the previous candidate in turn, its deadline honoured, its
--- complete chain verified against the frozen one, and its calls rendered once.
--- The plan is bound to this destination and this head; a moved head means a new
--- attempt, never an edited one.
--- @param root string The board checkout
--- @param frozen tx.Frozen The chain to publish
--- @param head string The fetched head to rebase onto
--- @param gate Gate | nil The bounded revalidation
--- @param now integer | nil The instant deadlines are judged at
--- @return Plan | nil The attempt, with its local candidate and calls
--- @return string Error message; "LOST_RACE: <path>" for a lost fence
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
    local entries, lerr = projection.snapshot(root, candidate, transition.changes)
    if entries == nil then return nil, lerr end
    snapshots[#snapshots + 1] = entries
    parent = candidate
  end
  local complete, cerr = receipts.complete_chain(root, parent, copy)
  if not complete then return nil, cerr end
  local plan: Plan = {format = "gitboard-state-plan-v2", frozen = copy, expected_head = head, expected_commit = expected_commit,
    base_tree = base, candidate = parent, publish_by = deadline, calls = {}, snapshots = snapshots}
  local rendered, rerr = render(plan)
  if rendered == nil then return nil, rerr end
  plan.calls = rendered
  return plan, ""
end
--- @param plan Exact saved attempt whose calls are regenerated and checked.
--- @return Fresh call records with execution guards, bound to that attempt.
local function connector_calls(plan: Plan, repository?: string, branch?: string): {Call} | nil, string
  local ok, err = validate(plan)
  if not ok then return nil, err end
  if (repository ~= nil and repository ~= plan.frozen.repository)
  or (branch ~= nil and branch ~= plan.frozen.branch) then return nil, "plan destination differs" end
  return render(plan)
end
--- @param index One-based call index in the frozen publication chain.
--- @return Connector arguments after the final-call deadline check.
local function connector_call(plan: Plan, index: integer, now?: integer): Call | nil, string
  local chain, err = connector_calls(plan)
  if chain == nil then return nil, err end
  if index < 1 or index > #chain then return nil, "call index outside plan" end
  if index == #chain and plan.publish_by > 0 and (now or os.time()) >= plan.publish_by then
    return nil, "prepared claim expired before publication"
  end
  local call = chain[index]
  return call, ""
end
--- `validate`, plus proof that this checkout's objects really are the attempt:
--- the candidate's first-parent chain has one commit per transition, starts at
--- the expected head, and each commit's tree matches the snapshot the plan
--- recorded. What a shell publication checks before pushing the candidate.
--- @param root string The board checkout
--- @param plan Plan The saved attempt
--- @return boolean True when the local objects match the attempt
--- @return string Error message
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
    local entries, lerr = projection.snapshot(root, tip, transition.changes)
    if entries == nil then return false, lerr end
    if literal.encode(entries) ~= literal.encode(plan.snapshots[index]) then return false, "saved snapshot differs from candidate tree" end
  end
  return true, ""
end
--- The commit a shell publication pushes, once the attempt and its local
--- objects are proven and its deadline has not passed.
--- @param root string The board checkout
--- @param plan Plan The saved attempt
--- @param now integer | nil The instant the deadline is judged at
--- @return string | nil The candidate commit to push
--- @return string Error message
local function local_candidate(root: string, plan: Plan, now?: integer): string | nil, string
  local ok, err = validate_local(root, plan)
  if not ok then return nil, err end
  if plan.publish_by > 0 and (now or os.time()) >= plan.publish_by then return nil, "prepared claim expired before publication" end
  return plan.candidate, ""
end
--- Write a validated attempt exactly once, sealed with its own digest so a
--- later load proves the bytes are the ones this call wrote.
--- @param path string Where to save it
--- @param plan Plan The attempt to freeze onto disk
--- @return boolean True when it was written
--- @return string Error message
local function save(path: string, plan: Plan): boolean, string
  local ok, err = validate(plan)
  if not ok then return false, err end
  local payload, perr = literal.encode(plan)
  if payload == nil then return false, perr end
  local raw, rerr = literal.encode({plan = plan, sha256 = objects.sha256(payload)})
  if raw == nil then return false, rerr end
  return saved.write_once(path, raw)
end
--- A saved attempt back from disk: the seal, then the plan's own validation,
--- then the canonical-bytes check — all three, in a protected call, because the
--- file is untrusted input a connector session may have carried around.
--- @param path string The saved attempt's path
--- @return Plan | nil The attempt
--- @return string Error message
local function load_saved(path: string): Plan | nil, string
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
  type Call = Call
  type Gate = Gate
  fence: function(root: string, head: string, transition: tx.Transition, gate?: Gate): boolean, string
  build: function(root: string, frozen: tx.Frozen, head: string, gate?: Gate, now?: integer): Plan | nil, string
  validate: function(Plan): boolean, string
  validate_local: function(string, Plan): boolean, string
  connector_calls: function(plan: Plan, repository?: string, branch?: string): {Call} | nil, string
  connector_call: function(plan: Plan, index: integer, now?: integer): Call | nil, string
  local_candidate: function(root: string, plan: Plan, now?: integer): string | nil, string
  save: function(string, Plan): boolean, string
  load: function(string): Plan | nil, string
end
local M: Module = {fence = fence, build = build, validate = validate, validate_local = validate_local, connector_calls = connector_calls,
  connector_call = connector_call, local_candidate = local_candidate, save = save, load = load_saved}
return M
