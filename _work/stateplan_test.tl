#!/usr/bin/env cosmic
local check = require("cosmic.check")
local fs = require("cosmic.fs")
local fixture = require("_work.fixture")
local git = require("_work.singlehead_git")
local objects = require("_work.singlehead_objects")
local tx = require("_work.statetransaction")
local projection = require("_work.stateplan_git")
local plans = require("_work.stateplan")
local receipts = require("_work.stateplan_receipts")
local literal = require("_work.singlehead_literal")
local ZERO < const > = string.rep("0", 40)
local function replay(root: string, plan: plans.Plan): string
  local outputs: {string: string} = {}
  local function resolve(raw: any): string
    assert(raw is string)
    return outputs[raw] or raw
  end
  local tip = ""
  for _, call in ipairs(check.must(plans.connector_calls(plan))) do
    local args = call.arguments
    if call.tool == "github_create_tree" then
      local base = args.base_tree_sha ~= nil and resolve(args.base_tree_sha)
      or check.must(objects.make_tree(root, {}))
      local changes: {tx.Change} = {}
      local entries = args.tree_elements as {{string: any}} -- cast: validated generated connector calls
      for _, entry in ipairs(entries) do
        local content = entry.content
        if content == nil then content = check.must(git.run(root, {"cat-file", "blob", resolve(entry.sha)})) end
        changes[#changes + 1] = {path = resolve(entry.path), mode = resolve(entry.mode), content = resolve(content), delete = false}
      end
      outputs["$" .. call.id .. ".sha"] = check.must(projection.apply(root, base, changes))
    elseif call.tool == "github_create_commit" then
      assert(args.author == nil)
      tip = check.must(git.text(root, {"commit-tree", resolve(args.tree_sha), "-p", resolve(args.parent_sha)}, resolve(args.message), {
            GIT_AUTHOR_NAME = "Connector", GIT_AUTHOR_EMAIL = "connector@example.test", GIT_AUTHOR_DATE = "1700000000 +0000",
            GIT_COMMITTER_NAME = "Connector", GIT_COMMITTER_EMAIL = "connector@example.test", GIT_COMMITTER_DATE = "1700000000 +0000"}))
      outputs["$" .. call.id .. ".sha"] = tip
    else
      assert(args.force == false and resolve(args.sha) == tip)
    end
  end
  return tip
end
local function initial(root: string): string
  assert(fs.make_dirs(root))
  check.must(git.run(root, {"init", "--quiet"}))
  local tree = check.must(objects.make_tree(root, {}))
  return check.must(objects.make_commit(root, tree, "initial\n"))
end
local function transition(base: string, path: string, text: string, id: string): tx.Transition
  return {base = base, dependencies = {{path = path, id = id}}, changes = {{path = path, mode = "100644", content = text, delete = false}},
    message = "edit by session head: test\n\nOp: edit\nTransaction: frozen-test\n",
    author = {name = "Session", email = "session@example.test", date = "1700000000 +0000"}, publish_by = 0, bounded = false, gate = ""}
end
local function frozen(base: string, chain: {tx.Transition}): tx.Frozen
  return {format = tx.FORMAT, repository = "example/board", branch = "state", remote = "origin",
    transaction = "frozen-test", staging_sha = base, transitions = chain}
end
local function test_frozen_chain_receipt_and_connector()
  local root = fs.join(fixture.tmpdir, "chain")
  local base = initial(root)
  local first = transition(base, "items/a/body", "one", ZERO)
  local tree = check.must(projection.apply(root, base, first.changes))
  local staged = check.must(projection.commit(root, base, tree, first))
  local second = transition(staged, "items/a/body", "two", check.must(projection.path_id(root, staged, "items/a/body")))
  second.changes[1].mode = "100755"
  local value = frozen(base, {first, second})
  local plan = check.must(plans.build(root, value, base))
  local connector_tip = replay(root, plan)
  assert(check.must(git.oid(root, connector_tip .. "^{tree}")) == check.must(git.oid(root, plan.candidate .. "^{tree}")))
  assert(check.must(receipts.inspect(root, connector_tip, plan.frozen)).status == "confirmed")
  assert(#plan.calls == 5)
  assert(plan.calls[3].arguments.base_tree_sha == "$tree_1_1.sha")
  assert(plan.calls[4].arguments.parent_sha == "$commit_1.sha")
  assert(plan.calls[5].arguments.force == false)
  local status = check.must(receipts.inspect(root, plan.candidate, value, plan.candidate, base))
  assert(status.status == "confirmed")
  local advanced = check.must(receipts.inspect(root, plan.candidate, value, plan.candidate, staged))
  assert(advanced.status == "pending")
  local squashedtree = check.must(git.oid(root, plan.candidate .. "^{tree}"))
  local squashed = check.must(projection.commit(root, base, squashedtree, second))
  assert(check.must(receipts.inspect(root, squashed, value, squashed)).status == "conflict")
  first.changes[1].content = "mutated caller"
  assert(plan.frozen.transitions[1].changes[1].content == "one")
  local saved = fs.join(fixture.tmpdir, "immutable.plan")
  assert(plans.save(saved, plan))
  assert(not plans.save(saved, plan))
  assert(check.must(plans.load(saved)).candidate == plan.candidate)
end
local function test_path_fence_precedes_bounded_gate_and_retry_is_new()
  local root = fs.join(fixture.tmpdir, "fences")
  local base = initial(root)
  local change = transition(base, "items/a/body", "a", ZERO)
  change.dependencies[#change.dependencies + 1] = {path = "claims/a", id = ZERO}
  change.bounded = true; change.gate = "doing-bound"
  local other = transition(base, "claims/a", "lease", ZERO)
  local moved = check.must(projection.commit(root, base, check.must(projection.apply(root, base, other.changes)), other))
  local called = false
  local function gate(_root: string, _head: string, _transition: tx.Transition): boolean, string
    called = true
    return true, ""
  end
  local original = check.must(plans.build(root, frozen(base, {change}), base, gate))
  local lost, err = plans.build(root, original.frozen, moved, gate)
  assert(lost == nil and err:find("LOST_RACE", 1, true) and not called)
  local disjoint = transition(base, "items/b/body", "b", ZERO)
  local unrelated = check.must(projection.commit(root, base, check.must(projection.apply(root, base, disjoint.changes)), disjoint))
  local retried = check.must(plans.build(root, original.frozen, unrelated, gate))
  assert(called and retried.expected_head == unrelated and original.expected_head == base)
  assert(check.must(projection.path_id(root, retried.candidate, "items/b/body")) ~= ZERO)
end
local function test_deadline_delete_author_and_read_dependency()
  local root = fs.join(fixture.tmpdir, "deadline")
  local base = initial(root)
  local create = transition(base, "items/a/body", "a", ZERO)
  local one = check.must(projection.commit(root, base, check.must(projection.apply(root, base, create.changes)), create))
  local remove = transition(one, "items/a/body", "", check.must(projection.path_id(root, one, "items/a/body")))
  remove.changes[1].delete = true
  remove.publish_by = 100
  local plan = check.must(plans.build(root, frozen(one, {remove}), one, nil, 99))
  local connector_tip = replay(root, plan)
  assert(check.must(git.oid(root, connector_tip .. "^{tree}")) == check.must(git.oid(root, plan.candidate .. "^{tree}")))
  assert(check.must(receipts.inspect(root, connector_tip, plan.frozen)).status == "confirmed")
  assert(plans.connector_call(plan, #plan.calls, 99))
  assert(not plans.connector_call(plan, #plan.calls, 100))
  assert(not plans.local_candidate(root, plan, 100))
  assert(check.must(projection.path_id(root, plan.candidate, "items/a/body")) == ZERO)
  assert(receipts.complete_chain(root, plan.candidate, plan.frozen))
  plan.frozen.transitions[1].author.name = "Other"
  assert(not receipts.complete_chain(root, plan.candidate, plan.frozen))
  assert(not plans.validate(plan))
  remove.dependencies = {}
  assert(not tx.validate(frozen(one, {remove})))
end
local function test_reserved_trailers_and_unsorted_changes()
  local root = fs.join(fixture.tmpdir, "reserved")
  local base = initial(root)
  local change = transition(base, "items/z/body", "z", ZERO)
  change.changes[#change.changes + 1] = {path = "items/a/body", mode = "100644", content = "a", delete = false}
  change.dependencies[#change.dependencies + 1] = {path = "items/a/body", id = ZERO}
  local plan = check.must(plans.build(root, frozen(base, {change}), base))
  assert(plan.frozen.transitions[1].changes[1].path == "items/a/body")
  assert(check.must(receipts.inspect(root, plan.candidate, plan.frozen)).status == "confirmed")
  local trailers = check.must(git.run(root, {"interpret-trailers", "--parse"}, plan.frozen.transitions[1].message))
  assert(trailers:find("Op: edit", 1, true))
  local author = (check.must(literal.encode(change.author))):gsub("\n$", "")
  change.message = "edit\n\nGitboard-Author: " .. author .. "\nTransaction: wrong\n"
  assert(not tx.freeze(frozen(base, {change})))
  change.message = "edit\n\nGitboard-Author: " .. author .. "\n"
  assert(not tx.freeze(frozen(base, {change})))
end
print("stateplan_test: ok")

local function test_deletion_refuses_inherited_gitlink()
  local root = fs.join(fixture.tmpdir, "gitlink-deletion")
  local base = initial(root)
  local blob = check.must(git.text(root, {"hash-object", "-w", "--stdin"}, "remove me"))
  local tree = check.must(git.text(root, {"mktree"}, "100644 blob " .. blob .. "\tremove\n160000 commit " .. base .. "\tunsupported-submodule\n"))
  local inherited = check.must(objects.make_commit(root, tree, "inherited gitlink\n", base))
  local change = transition(inherited, "remove", "", blob)
  change.changes[1].delete = true
  local plan, err = plans.build(root, frozen(inherited, {change}), inherited)
  assert(plan == nil and err:find("unsupported native tree entry", 1, true), "deletion must never silently omit an inherited gitlink")
end
