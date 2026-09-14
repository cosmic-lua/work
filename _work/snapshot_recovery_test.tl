#!/usr/bin/env cosmic
local check = require("cosmic.check")
local fs = require("cosmic.fs")
local fixture = require("_work.fixture")
local git = require("_work.singlehead_git")
local literal = require("_work.singlehead_literal")
local objects = require("_work.stateplan_objects")
local projection = require("_work.stateplan_git")
local protocol = require("_work.snapshot_protocol")
local recovery = require("_work.snapshot_recovery")
local snapshot = require("_work.snapshot")
local tx = require("_work.statetransaction")

local AUTHOR: snapshot.Author = {name = "Session", email = "session@example.test",
  date = "1700000000 +0000"}

local function logical_message(subject: string, author?: snapshot.Author): string
  local encoded = check.must(literal.encode(author or AUTHOR)):gsub("\n$", "")
  return subject .. "\n\nGitboard-Author: " .. encoded .. "\n"
end

local function setup(name: string, deadline?: integer): string, snapshot.Plan
  local root = fs.join(fixture.tmpdir, "snapshot-recovery-" .. name)
  assert(fs.remove_all(root)); assert(fs.make_dirs(root))
  check.must(git.run(root, {"init", "--quiet"}))
  local base = check.must(objects.make_commit(root,
      check.must(objects.make_tree(root, {})), "base\n"))
  local change: tx.Change = {path = "item", mode = "100644", content = "new",
    delete = false}
  local tree = check.must(projection.apply(root, base, {change}))
  local local_commit = check.must(git.text(root, {"commit-tree", tree, "-p", base},
      logical_message("update item"), {GIT_AUTHOR_NAME = AUTHOR.name,
        GIT_AUTHOR_EMAIL = AUTHOR.email, GIT_AUTHOR_DATE = AUTHOR.date,
        GIT_COMMITTER_NAME = "gitboard", GIT_COMMITTER_EMAIL = "gitboard@localhost",
        GIT_COMMITTER_DATE = AUTHOR.date}))
  local destination: snapshot.Destination = {repository = "example/board",
    branch = "state", remote = "origin",
    target_url = "https://github.com/example/board.git"}
  local function validate(_root: string, _parent: string,
      _commit: string): integer | nil, string
    return deadline or 0, ""
  end
  return root, check.must(snapshot.capture(root, local_commit, destination, validate))
end

local function provider_commit(root: string, parent: string, tree: string,
    message: string): string
  return check.must(git.text(root, {"commit-tree", tree, "-p", parent}, message, {
        GIT_AUTHOR_NAME = "Connector", GIT_AUTHOR_EMAIL = "connector@provider.test",
        GIT_AUTHOR_DATE = "1700000001 +0000", GIT_COMMITTER_NAME = "Connector",
        GIT_COMMITTER_EMAIL = "connector@provider.test",
        GIT_COMMITTER_DATE = "1700000001 +0000"}))
end

local function state(plan: snapshot.Plan, sha: string,
    phase?: string): recovery.Recovery
  return {format = recovery.FORMAT, phase = phase or "updating",
    local_commit = plan.local_commit, repository = plan.destination.repository,
    branch = plan.destination.branch, remote = plan.destination.remote,
    target_url = plan.destination.target_url, remote_sha = sha}
end

local function test_provider_sha_difference_confirms_exact_identity()
  local root, plan = setup("provider")
  local remote = provider_commit(root, plan.parent, plan.tree, plan.message)
  assert(remote ~= plan.local_commit, "connector physical author should change SHA")
  local status = check.must(recovery.reconcile(root, remote, plan, state(plan, remote)))
  assert(status.status == "confirmed" and status.candidate == remote)
  local child = provider_commit(root, remote, plan.tree, logical_message("later"))
  assert(check.must(recovery.reconcile(root, child, plan,
        state(plan, remote))).status == "confirmed",
    "canonical first-parent descendants preserve confirmation")
end
test_provider_sha_difference_confirms_exact_identity()

local function test_wrong_identity_and_side_branch_never_confirm()
  local root, plan = setup("identity")
  local other_base = check.must(objects.make_commit(root,
      check.must(objects.make_tree(root, {})), "other root\n"))
  local wrong_parent = provider_commit(root, other_base, plan.tree, plan.message)
  assert(check.must(recovery.reconcile(root, wrong_parent, plan,
        state(plan, wrong_parent))).status == "conflict")

  local changed_tree = check.must(projection.apply(root, plan.parent,
      {{path = "item", mode = "100644", content = "wrong", delete = false}}))
  local wrong_tree = provider_commit(root, plan.parent, changed_tree, plan.message)
  assert(check.must(recovery.reconcile(root, wrong_tree, plan,
        state(plan, wrong_tree))).status == "conflict")

  local wrong_message = provider_commit(root, plan.parent, plan.tree,
    logical_message("different summary"))
  assert(check.must(recovery.reconcile(root, wrong_message, plan,
        state(plan, wrong_message))).status == "conflict")

  local stranger: snapshot.Author = {name = "Other", email = "other@example.test",
    date = AUTHOR.date}
  local wrong_author = provider_commit(root, plan.parent, plan.tree,
    logical_message("update item", stranger))
  assert(check.must(recovery.reconcile(root, wrong_author, plan,
        state(plan, wrong_author))).status == "conflict")

  local exact = provider_commit(root, plan.parent, plan.tree, plan.message)
  local descendant = provider_commit(root, exact, plan.tree,
    logical_message("later canonical change"))
  local rediscovered = check.must(recovery.discover(root, descendant, plan))
  assert(rediscovered.status == "confirmed" and rediscovered.candidate == exact,
    "cleaned recovery is reconstructed from the exact first-parent child")
  assert(check.must(recovery.discover(root, wrong_message, plan)).status == "conflict",
    "matching parent alone cannot reconstruct a cleaned attempt")
  assert(check.must(recovery.discover(root, other_base, plan)).status == "uncertain",
    "history that does not reach the parent cannot prove absence")
  local unrelated = provider_commit(root, plan.parent, plan.base_tree,
    logical_message("unrelated advance"))
  local side = check.must(recovery.reconcile(root, unrelated, plan, state(plan, exact)))
  assert(side.status == "conflict" and side.reason:find("first%-parent"),
    "an exact candidate on a side branch is not publication")
  local absent = state(plan, string.rep("a", 40))
  assert(check.must(recovery.reconcile(root, unrelated, plan, absent)).status
    == "conflict", "complete history proves an absent returned SHA lost the race")

  local shallow_root, shallow_plan = setup("shallow")
  local shallow_head = provider_commit(shallow_root, shallow_plan.parent,
    shallow_plan.base_tree, logical_message("shallow advance"))
  assert(fs.write(fs.join(shallow_root, ".git/shallow"), shallow_head .. "\n"))
  local incomplete = check.must(recovery.reconcile(shallow_root, shallow_head,
      shallow_plan, state(shallow_plan, string.rep("b", 40))))
  assert(incomplete.status == "uncertain"
    and incomplete.reason:find("does not reach", 1, true),
    "a shallow boundary cannot prove candidate absence")
end
test_wrong_identity_and_side_branch_never_confirm()

local function test_durable_phases_lost_response_and_no_duplicate()
  local root, plan = setup("durable")
  local path = fs.join(root, "recovery.literal")
  local prepared = check.must(recovery.begin(path, plan))
  assert(prepared.phase == "prepared")
  local before = check.must(recovery.reconcile(root, plan.parent, plan, prepared))
  assert(before.status == "uncertain" and before.reason:find("may be repeated", 1, true))

  local remote = provider_commit(root, plan.parent, plan.tree, plan.message)
  local candidate = check.must(recovery.record_candidate(path, plan, remote))
  local call = check.must(protocol.arm_update(path, plan, candidate, plan.parent, 1))
  assert(call.arguments.sha == remote and call.arguments.force == false)
  local loaded = check.must(recovery.load(path))
  assert(loaded.phase == "updating" and loaded.remote_sha == remote,
    "remote SHA and uncertainty must be durable before update_ref")

  -- Model a successful ref update whose response is lost.  Reconciliation of
  -- the fetched canonical head confirms before any retry is considered.
  local after = check.must(recovery.reconcile(root, remote, plan, loaded))
  assert(after.status == "confirmed")
  local duplicate, derr = protocol.arm_update(path, plan, candidate, plan.parent, 1)
  assert(duplicate == nil and derr:find("already uncertain", 1, true), derr)
end
test_durable_phases_lost_response_and_no_duplicate()

local function test_recovery_binding_io_head_and_deadline_refusals()
  local root, plan = setup("refusals", 10)
  local missing, merr = recovery.load(fs.join(root, "missing.literal"))
  assert(missing == nil and merr ~= "")
  local malformed_path = fs.join(root, "malformed.literal")
  assert(fs.write(malformed_path, "not a literal"))
  local malformed, ferr = recovery.load(malformed_path)
  assert(malformed == nil and ferr ~= "")

  local broken_path = fs.join(root, "broken.literal")
  check.must(recovery.begin(broken_path, plan))
  local broken_remote = provider_commit(root, plan.parent, plan.tree, plan.message)
  check.must(recovery.record_candidate(broken_path, plan, broken_remote))
  assert(fs.remove(broken_path))
  local broken, berr = recovery.load(broken_path)
  assert(broken == nil and berr ~= "",
    "a phase sidecar cannot stand without its prepared record")

  local foreign_path = fs.join(root, "foreign.literal")
  check.must(recovery.begin(foreign_path, plan))
  local foreign_sidecar = state(plan, broken_remote, "candidate")
  foreign_sidecar.target_url = foreign_sidecar.target_url .. "/other"
  assert(fs.write(foreign_path .. ".candidate",
      check.must(literal.encode(foreign_sidecar))))
  local incoherent, ierr = recovery.load(foreign_path)
  assert(incoherent == nil and ierr:find("does not continue", 1, true), ierr)

  local path = fs.join(root, "attempt.literal")
  check.must(recovery.begin(path, plan))
  local remote = provider_commit(root, plan.parent, plan.tree, plan.message)
  local candidate = check.must(recovery.record_candidate(path, plan, remote))
  local foreign = state(plan, remote, "candidate")
  foreign.target_url = foreign.target_url .. "/wrong"
  local wrong, werr = protocol.arm_update(path, plan, foreign, plan.parent, 9)
  assert(wrong == nil and werr:find("destination", 1, true), werr)

  local moved = provider_commit(root, plan.parent, plan.base_tree,
    logical_message("disjoint"))
  local stale, serr = protocol.arm_update(path, plan, candidate, moved, 9)
  assert(stale == nil and serr:find("advanced", 1, true), serr)
  local expired, eerr = protocol.arm_update(path, plan, candidate, plan.parent, 10)
  assert(expired == nil and eerr:find("expired", 1, true), eerr)
end
test_recovery_binding_io_head_and_deadline_refusals()
