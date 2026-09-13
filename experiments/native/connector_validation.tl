#!/usr/bin/env cosmic
--- Local-only proof driver. Only the dedicated validation branch is emitted.
local check = require("cosmic.check")
local fs = require("cosmic.fs")
local json = require("cosmic.json")
local wire = require("_work.singlehead_literal")
local saved = require("_work.stateplan_file")
local git = require("_work.singlehead_git")
local stateinit = require("_work.stateinit")
local boardtree = require("_work.boardtree")
local boardread = require("_work.boardread")
local tx = require("_work.statetransaction")
local projection = require("_work.stateplan_git")
local plans = require("_work.stateplan")
local receipts = require("_work.stateplan_receipts")
local ksuid = require("_work.ksuid")
local claim = require("_work.claim")
local stateclaim = require("_work.stateclaim")
local item = require("_work.item")
local refs = require("_work.refs")
local store = require("_work.store")
local native_authority = require("_work.stateclaim_authority")
local BRANCH < const > = "validation/gitboard-format6-20260913"
local REPOSITORY < const > = "cosmic-lua/work"
local SESSION < const > = "connector-format6-validation"
local function write(path: string, value: any)
  assert(saved.write_once(path, check.must(wire.encode(value))))
end
local function show(value: any)
  print(check.must(wire.encode(value)))
end
local function checked_plan(root: string, path: string): plans.Plan
  local plan = check.must(plans.load(path))
  assert(plan.frozen.branch == BRANCH and plan.frozen.repository == REPOSITORY, "unexpected validation destination")
  assert(plans.validate_local(root, plan))
  return plan
end
local function transition(root: string, base: string, id: string, path: string, content: string,
    verb: string, deleted?: boolean): tx.Transition
  return {base = base, dependencies = {
      {path = "items/" .. id, id = check.must(projection.path_id(root, base, "items/" .. id))},
      {path = "claims/" .. id, id = check.must(projection.path_id(root, base, "claims/" .. id))}},
    changes = {{path = path, mode = "100644", content = content, delete = deleted or false}},
    message = verb .. " by " .. SESSION .. " head: validation\n\n" .. content .. "\n\nOp: " .. verb .. "\n",
    author = {name = SESSION, email = "validation@cosmic-lua.invalid", date = tostring(os.time()) .. " +0000"},
    publish_by = 0, bounded = false, gate = ""}
end
local function seed(root: string, parent: string, out: string)
  assert(stateinit.init(root))
  assert(refs.set_board_mode(root, "local"))
  check.must(git.run(root, {"config", "gitboard.validation-only", BRANCH}))
  local head = check.must(git.oid(root, "refs/heads/state"))
  local view = check.must(boardread.list(root, head))
  local root_item = view.items[1]
  local child_id = ksuid.new()
  local child_item = check.must(wire.decode_object(check.must(wire.encode(root_item)))) as item.Item -- cast: exact item literal roundtrip
  child_item.id, child_item.parent, child_item.title = child_id, root_item.id, "connector validation child"
  root_item.order = {child_id}
  local changes: {tx.Change} = {}
  for _, it in ipairs({root_item, child_item}) do
    local tree = check.must(boardtree.build_item(root, it, nil, nil, true))
    for _, entry in ipairs(check.must(boardtree.snapshot_entries(root, tree))) do
      changes[#changes + 1] = {path = "items/" .. it.id .. "/" .. entry.path, mode = entry.mode,
        content = check.must(git.run(root, {"cat-file", "blob", entry.sha})), delete = false}
    end
  end
  local tree = check.must(projection.apply(root, head, changes))
  local entries = wire.sequence() as {{string: any}} -- cast: connector sequence
  for _, entry in ipairs(check.must(boardtree.snapshot_entries(root, tree))) do
    entries[#entries + 1] = {path = entry.path, mode = entry.mode, type = "blob",
      content = check.must(git.run(root, {"cat-file", "blob", entry.sha}))}
  end
  write(fs.join(out, "seed-tree.literal"), {id = "seed_tree", tool = "github_create_tree", arguments = {repository_full_name = REPOSITORY, tree_elements = entries}})
  write(fs.join(out, "seed-commit.literal"), {id = "seed_commit", tool = "github_create_commit", arguments = {repository_full_name = REPOSITORY,
        parent_sha = parent, tree_sha = "$seed_tree.sha", message = "initialize isolated format-6 connector validation"}})
  write(fs.join(out, "seed.literal"), {repository = REPOSITORY, branch = BRANCH, parent = parent, tree = tree, root_item = root_item.id, child_item = child_id})
  show({tree = tree, root_item = root_item.id, child_item = child_id, branch = BRANCH})
end
local function make_plan(root: string, head: string, out: string, action: string, item_id?: string)
  local view = check.must(boardread.list(root, head))
  local id = item_id or ""
  if id == "" then
    for _, it in ipairs(view.items) do if it.parent ~= "" then id = it.id end end
  end
  assert(view.items_by_id[id], "validation item missing")
  local chain: {tx.Transition} = {}
  local transaction = "connector-" .. action .. "-" .. ksuid.new()
  if action == "log" or action == "draft" then
    local number = action == "draft" and 2 or 1
    local parent = head
    for index = 1, number do
      local text = "Format-6 connector " .. action .. " transition " .. tostring(index) .. ".\n"
      local change = transition(root, parent, id, "items/" .. id .. "/log/" .. ksuid.new() .. ".md", text, "log")
      chain[#chain + 1] = change
      parent = check.must(projection.commit(root, parent, check.must(projection.apply(root, parent, change.changes)), change))
    end
  elseif action == "claim" then
    assert(view.claims_by_id[id] == nil, "validation claim already exists")
    local now = os.time()
    local body = check.must(boardtree.encode_claim({id = boardtree.mint_claim_id(), holder = SESSION,
          acquired_at = now, renewed_at = now, expires_at = now + 3600, product_base = head}))
    local change = transition(root, head, id, "claims/" .. id, body, "take")
    change.publish_by = now + 3600
    change.bounded = true; change.gate = "validation-doing-bound"
    chain = {change}
  elseif action == "drop" then
    assert(view.claims_by_id[id], "validation claim is missing")
    chain = {transition(root, head, id, "claims/" .. id, "", "drop", true)}
  else error("action must be log, draft, claim, or drop") end
  local frozen: tx.Frozen = {format = tx.FORMAT, repository = REPOSITORY, branch = BRANCH, remote = "validation",
    transaction = transaction, staging_sha = head, transitions = chain}
  local plan = check.must(plans.build(root, frozen, head))
  assert(plans.save(fs.join(out, "plan.literal"), plan))
  write(fs.join(out, "calls.literal"), check.must(plans.connector_calls(plan, REPOSITORY, BRANCH)))
  show({transaction = transaction, calls = #plan.calls, candidate = plan.candidate, head = head, item = id,
      deadline = plan.publish_by, plan = fs.join(out, "plan.literal")})
end
local function verify(root: string, head: string, path: string, returned: string)
  local plan = checked_plan(root, path)
  local observed = check.must(receipts.inspect(root, head, plan.frozen, returned, plan.frozen.staging_sha))
  assert(observed.status == "confirmed", observed.reason)
  local view = check.must(boardread.list(root, head))
  assert(check.must(git.text(root, {"config", "--get", "gitboard.validation-only"})) == BRANCH, "local authority projection requires isolated validation repo")
  check.must(git.run(root, {"update-ref", "refs/heads/state", head}))
  local state = check.must(store.open(root))
  local authority: {string: string} = {}
  for _, it in ipairs(view.items) do
    local current = stateclaim.state(view.claims_by_id[it.id])
    authority[it.id] = claim.status(current, os.time())
    local authorized = native_authority.current(state, it.id, SESSION)
    assert((authorized ~= nil) == (authority[it.id] == "active" and current ~= nil and current.holder == SESSION), "canonical claim authority disagrees")
  end
  local changed = check.must(receipts.inspect(root, head, plan.frozen, returned, plan.candidate))
  assert(changed.status == "pending", "advanced draft must remain pending")
  show({receipt = observed.status, returned = returned, head = head, authority = authority,
      advanced_draft = changed.status, expected_tree = check.must(git.oid(root, plan.candidate .. "^{tree}")),
      actual_tree = check.must(git.oid(root, returned .. "^{tree}"))})
  assert(check.must(git.oid(root, plan.candidate .. "^{tree}")) == check.must(git.oid(root, returned .. "^{tree}")), "connector tree differs")
end
local function race(root: string, path: string, head: string)
  local plan = checked_plan(root, path)
  local gates = 0
  local function reject(_root: string, _head: string, _transition: tx.Transition): boolean, string
    gates = gates + 1
    return false, "validation bounded gate refused moved board"
  end
  local next_plan, err = plans.build(root, plan.frozen, head, reject)
  assert(next_plan == nil, "stale validation attempt unexpectedly planned")
  show({refused = err, gate_calls = gates, original_head = plan.expected_head, moved_head = head})
end
local mode = arg[1] or ""
if mode == "seed" then seed(assert(arg[2]), assert(arg[3]), assert(arg[4]))
elseif mode == "plan" then make_plan(assert(arg[2]), assert(arg[3]), assert(arg[4]), assert(arg[5]), arg[6])
elseif mode == "verify" then verify(assert(arg[2]), assert(arg[3]), assert(arg[4]), assert(arg[5]))
elseif mode == "race" then race(assert(arg[2]), assert(arg[3]), assert(arg[4]))
elseif mode == "call" then
  local root, path, index = assert(arg[2]), assert(arg[3]), assert(math.tointeger(tonumber(arg[4])))
  local plan = checked_plan(root, path)
  show(check.must(plans.connector_call(plan, index)))
elseif mode == "json" then
  local value = check.must(wire.decode(check.must(fs.read(assert(arg[2])))))
  print(check.must(json.encode(value)))
else error("usage: connector_validation seed|plan|verify|race|call|json ...") end
