#!/usr/bin/env cosmic
--- Different local/global trailer policies cannot rewrite an immutable attempt.
local check = require("cosmic.check")
local fs = require("cosmic.fs")
local env = require("cosmic.env")
local fixture = require("_work.fixture")
local git = require("_work.singlehead_git")
local objects = require("_work.singlehead_objects")
local tx = require("_work.statetransaction")
local projection = require("_work.stateplan_git")
local plans = require("_work.stateplan")
local receipts = require("_work.stateplan_receipts")
local literal = require("_work.singlehead_literal")
local function test_freeze_and_capture_ignore_ambient_trailer_configuration()
  local root = fs.join(fixture.tmpdir, "trailer-config")
  assert(fs.remove_all(root)); assert(fs.make_dirs(root))
  check.must(git.run(root, {"init", "--quiet"}))
  local base = check.must(objects.make_commit(root, check.must(objects.make_tree(root, {})), "base\n"))
  local change: tx.Transition = {base = base, dependencies = {{path = "items/a/body", id = string.rep("0", 40)}},
    changes = {{path = "items/a/body", mode = "100644", content = "one", delete = false}}, message = "edit\n\nOp: edit\n",
    author = {name = "Session", email = "session@example.test", date = "1700000000 +0000"}, publish_by = 0, bounded = false, gate = ""}
  local frozen: tx.Frozen = {format = tx.FORMAT, repository = "example/board", branch = "state", remote = "origin",
    transaction = "config-proof", staging_sha = base, transitions = {change}}
  local plan = check.must(plans.build(root, frozen, base))
  local config = fs.join(root, "hostile.gitconfig")
  assert(fs.write(config, "[trailer]\n separators = %\n where = start\n ifExists = doNothing\n[trailer \"Transaction\"]\n key = Poisoned-Transaction\n[trailer \"Gitboard-Author\"]\n key = Poisoned-Author\n[core]\n commentChar = !\n"))
  check.must(git.run(root, {"config", "trailer.separators", "%"}))
  check.must(git.run(root, {"config", "trailer.Transaction.key", "Other-Transaction"}))
  local prior = os.getenv("GIT_CONFIG_GLOBAL")
  assert(env.set("GIT_CONFIG_GLOBAL", config))
  local function verify_config()
    local refrozen = check.must(tx.freeze(frozen))
    assert(literal.encode(refrozen) == literal.encode(plan.frozen), "ambient configuration changed frozen bytes")
    local observed = check.must(projection.capture(root, base, plan.candidate, {}))
    assert(observed.message == plan.frozen.transitions[1].message)
    assert(observed.author.name == "Session")
    assert(check.must(receipts.inspect(root, plan.candidate, plan.frozen)).status == "confirmed")
    local final_guard = check.must(plans.connector_call(plan, #plan.calls)).guard
    assert(final_guard ~= nil and final_guard.expected_head == base)
    local changed = check.must(tx.freeze(plan.frozen))
    changed.transitions[1].message = "edit\n\nTransaction: wrong\n"
    assert(not tx.validate(changed), "Transaction mismatch must fail without logical author")
    assert(not tx.freeze(changed), "freeze must not silently replace another transaction identity")
    changed.transitions[1].message = "edit\n\nTransaction: config-proof\nTransaction: config-proof\n"
    assert(not tx.validate(changed), "duplicate Transaction must fail without logical author")
  end
  local ok, err = pcall(verify_config)
  if prior == nil then assert(env.unset("GIT_CONFIG_GLOBAL")) else assert(env.set("GIT_CONFIG_GLOBAL", prior)) end
  assert(ok, err)
end
