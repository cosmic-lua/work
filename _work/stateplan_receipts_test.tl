#!/usr/bin/env cosmic
--- Final transition equality cannot prove that its earlier prefix was published.
local check = require("cosmic.check")
local fs = require("cosmic.fs")
local fixture = require("_work.fixture")
local git = require("_work.singlehead_git")
local objects = require("_work.stateplan_objects")
local tx = require("_work.statetransaction")
local projection = require("_work.stateplan_git")
local plans = require("_work.stateplan")
local receipts = require("_work.stateplan_receipts")
local function test_exact_final_transition_does_not_authorize_counterfeit_prefix()
  local root = fs.join(fixture.tmpdir, "native-receipt-prefix")
  assert(fs.remove_all(root)); assert(fs.make_dirs(root))
  check.must(git.run(root, {"init", "--quiet"}))
  local base = check.must(objects.make_commit(root, check.must(objects.make_tree(root, {})), "base\n"))
  local first: tx.Transition = {base = base, dependencies = {{path = "items/a/body", id = string.rep("0", 40)}},
    changes = {{path = "items/a/body", mode = "100644", content = "one", delete = false}},
    message = "first\n", author = {name = "Session", email = "session@example.test", date = "1700000000 +0000"},
    publish_by = 0, bounded = false, gate = ""}
  local first_tree = check.must(projection.apply(root, base, first.changes))
  local staged = check.must(projection.commit(root, base, first_tree, first))
  local second: tx.Transition = {base = staged,
    dependencies = {{path = "items/a/body", id = check.must(projection.path_id(root, staged, "items/a/body"))}},
    changes = {{path = "items/a/body", mode = "100644", content = "two", delete = false}},
    message = "second\n", author = first.author, publish_by = 0, bounded = false, gate = ""}
  local frozen: tx.Frozen = {format = tx.FORMAT, repository = "example/board", branch = "state", remote = "origin",
    transaction = "prefix-proof", staging_sha = base, transitions = {first, second}}
  local plan = check.must(plans.build(root, frozen, base))
  assert(check.must(receipts.inspect(root, plan.candidate, plan.frozen)).status == "confirmed")
  local published_prefix = check.must(git.oid(root, plan.candidate .. "~1"))
  local prefix = check.must(receipts.inspect(root, published_prefix, plan.frozen))
  assert(prefix.status == "prefix" and prefix.prefix == 1,
    "an exact proper leading chain remains distinguishable from full confirmation")
  assert(check.must(receipts.inspect(root, published_prefix, plan.frozen,
        published_prefix)).status == "conflict",
    "a provider-returned final SHA is never silently downgraded to a partial publication")
  local malformed_suffix = check.must(tx.freeze(plan.frozen)).transitions[2]
  malformed_suffix.changes[1].content = "counterfeit second transition"
  local malformed_tree = check.must(projection.apply(root, published_prefix,
      malformed_suffix.changes))
  local malformed_tip = check.must(projection.commit(root, published_prefix,
      malformed_tree, malformed_suffix))
  assert(check.must(receipts.inspect(root, malformed_tip,
        plan.frozen)).status == "conflict",
    "a newer malformed same-transaction commit must not expose an older valid prefix")
  local counterfeit = check.must(tx.freeze(plan.frozen)).transitions[1]
  counterfeit.message = "a different earlier operation\n"
  local false_prefix = check.must(projection.commit(root, base, first_tree, counterfeit))
  local final_tree = check.must(projection.apply(root, false_prefix, plan.frozen.transitions[2].changes))
  local false_chain = check.must(projection.commit(root, false_prefix, final_tree, plan.frozen.transitions[2]))
  -- The exact tip tree, logical author, message, and diff all match. Only the
  -- frozen earlier transition distinguishes this counterfeit chain.
  assert(check.must(git.oid(root, false_chain .. "^{tree}")) == check.must(git.oid(root, plan.candidate .. "^{tree}")))
  assert(check.must(receipts.inspect(root, false_chain, plan.frozen, false_chain)).status == "conflict",
    "a matching final transition must not hide a counterfeit first-parent prefix")
end

local function test_message_only_mismatch_is_not_a_receipt()
  local root = fs.join(fixture.tmpdir, "native-message-only")
  assert(fs.remove_all(root)); assert(fs.make_dirs(root))
  check.must(git.run(root, {"init", "--quiet"}))
  local base = check.must(objects.make_commit(root, check.must(objects.make_tree(root, {})), "base\n"))
  local transition: tx.Transition = {base = base, dependencies = {{path = "items/a/body", id = string.rep("0", 40)}},
    changes = {{path = "items/a/body", mode = "100644", content = "identical bytes", delete = false}}, message = "expected subject\n\nOp: edit\n",
    author = {name = "Session", email = "session@example.test", date = "1700000000 +0000"}, publish_by = 0, bounded = false, gate = ""}
  local frozen: tx.Frozen = {format = tx.FORMAT, repository = "example/board", branch = "state", remote = "origin",
    transaction = "message-only", staging_sha = base, transitions = {transition}}
  local plan = check.must(plans.build(root, frozen, base))
  local counterfeit = check.must(tx.freeze(plan.frozen)).transitions[1]
  counterfeit.message = counterfeit.message:gsub("^expected subject", "different subject")
  local tree = check.must(git.oid(root, plan.candidate .. "^{tree}"))
  local different = check.must(projection.commit(root, base, tree, counterfeit))
  local observed = check.must(projection.capture(root, base, different, {}))
  assert(observed.author.name == plan.frozen.transitions[1].author.name)
  assert(observed.author.email == plan.frozen.transitions[1].author.email)
  assert(observed.author.date == plan.frozen.transitions[1].author.date)
  assert(observed.changes[1].content == plan.frozen.transitions[1].changes[1].content)
  assert(observed.changes[1].mode == plan.frozen.transitions[1].changes[1].mode)
  assert(observed.message ~= plan.frozen.transitions[1].message)
  assert(not receipts.complete_chain(root, different, plan.frozen), "message equality is independent of identical tree/author/parents")
  assert(check.must(receipts.inspect(root, different, plan.frozen, different)).status == "conflict")
end

local function test_receipt_search_excludes_base_and_caps_new_generations()
  local root = fs.join(fixture.tmpdir, "native-search-bound")
  assert(fs.remove_all(root)); assert(fs.make_dirs(root))
  check.must(git.run(root, {"init", "--quiet"}))
  local base = check.must(objects.make_commit(root, check.must(objects.make_tree(root, {})), "old misleading receipt\n\nTransaction: search-bound\n"))
  local transition: tx.Transition = {base = base, dependencies = {{path = "items/a/body", id = string.rep("0", 40)}},
    changes = {{path = "items/a/body", mode = "100644", content = "new", delete = false}}, message = "new\n",
    author = {name = "Session", email = "session@example.test", date = "1700000000 +0000"}, publish_by = 0, bounded = false, gate = ""}
  local frozen: tx.Frozen = {format = tx.FORMAT, repository = "example/board", branch = "state", remote = "origin",
    transaction = "search-bound", staging_sha = base, transitions = {transition}}
  local plan = check.must(plans.build(root, frozen, base))
  assert(check.must(receipts.inspect(root, base, plan.frozen)).status == "pending", "the staged base is outside receipt search")
  local unrelated = check.must(objects.make_commit(root, check.must(objects.make_tree(root, {})), "unrelated root\n"))
  assert(not check.must(receipts.inspect(root, unrelated, plan.frozen)).absence_proven, "an unrelated or truncated history cannot establish publication absence")
  local stream: {string} = {}
  for index = 1, receipts.SEARCH_LIMIT + 1 do
    local message = "unrelated generation " .. tostring(index) .. "\n"
    stream[#stream + 1] = "commit refs/heads/receipt-noise\ncommitter Noise <noise@example.test> 1700000000 +0000\ndata " .. tostring(#message) .. "\n" .. message
    if index == 1 then stream[#stream + 1] = "from " .. plan.candidate .. "\n" end
    stream[#stream + 1] = "\n"
  end
  check.must(git.run(root, {"fast-import", "--quiet"}, table.concat(stream)))
  local head = check.must(git.oid(root, "refs/heads/receipt-noise"))
  local recorded = check.must(receipts.inspect(root, head, plan.frozen, plan.candidate))
  assert(recorded.status == "confirmed", "recorded returned SHA must not expire with unrelated generations")
  local observed = check.must(receipts.inspect(root, head, plan.frozen))
  assert(observed.status == "pending" and observed.reason:find("limit", 1, true), "bounded search cannot retire an unverified attempt")
  assert(not observed.absence_proven)
end
