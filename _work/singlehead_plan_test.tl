#!/usr/bin/env cosmic
--- Real-Git race coverage for immutable single-head plans. Three writers plan
--- from one exact envelope head: one winner, one disjoint retry, and one
--- overlapping loser. All publication uses ordinary non-forced local pushes.
local check = require("cosmic.check")
local fs = require("cosmic.fs")
local git = require("_work.singlehead_git")
local objects = require("_work.singlehead_objects")
local plans = require("_work.singlehead_plan")
local refs = require("_work.refs")

local REPOSITORY < const > = "example/board"
local BRANCH < const > = "envelope-races"
local A_REF < const > = "refs/heads/items/a"
local B_REF < const > = "refs/heads/items/b"

local function git_ok(root: string, argv: {string}): string
  return check.must(git.text(root, argv))
end

local function commit(root: string, message: string, parent?: string): string
  local tree = check.must(objects.make_tree(root, {}))
  return check.must(objects.make_commit(root, tree, message, parent))
end

local function writer(path: string, source: string, envelope: string): string
  assert(fs.make_dirs(path))
  git_ok(path, {"init", "--quiet", "--object-format=sha1"})
  git_ok(path, {"remote", "add", "board", source})
  git_ok(path, {"fetch", "--quiet", "board",
      "+refs/heads/*:refs/remotes/board/*"})
  git_ok(path, {"remote", "add", "envelope", envelope})
  git_ok(path, {"fetch", "--quiet", "envelope",
      "+refs/heads/" .. BRANCH .. ":refs/remotes/envelope/" .. BRANCH})
  return git_ok(path, {"rev-parse", "refs/remotes/envelope/" .. BRANCH})
end

local function push(root: string, candidate: string): string | nil, string
  return git.run(root, {"push", "--quiet", "envelope",
      candidate .. ":refs/heads/" .. BRANCH})
end

local function update(ref: string, expected: string,
    next_sha: string): objects.Update
  return {ref = ref, expected = expected, next = next_sha}
end

local function build(root: string, head: string, id: string,
    change: objects.Update): plans.Plan | nil, string
  return plans.build(root, root, head, id, {change}, REPOSITORY, BRANCH,
    change.next, {}, false)
end

local function test_nonforced_races_retry_only_disjoint_original_transaction()
  local tmp = assert(os.getenv("TEST_TMPDIR"))
  local source, envelope = fs.join(tmp, "source"), fs.join(tmp, "envelope.git")
  assert(fs.make_dirs(source) and fs.make_dirs(envelope))
  git_ok(source, {"init", "--quiet", "--object-format=sha1"})
  git_ok(envelope, {"init", "--quiet", "--bare", "--object-format=sha1"})
  local a0, b0 = commit(source, "initial a"), commit(source, "initial b")
  assert(refs.update_ref(source, A_REF, a0, refs.ZERO_SHA))
  assert(refs.update_ref(source, B_REF, b0, refs.ZERO_SHA))
  git_ok(source, {"remote", "add", "envelope", envelope})
  local empty = commit(source, "empty envelope root")
  git_ok(source, {"push", "--quiet", "envelope",
      empty .. ":refs/heads/" .. BRANCH})
  local seed = check.must(plans.build_seed(source, source, empty,
      "refs/heads/", REPOSITORY, BRANCH))
  local same_head = check.must(plans.local_candidate(source, seed))
  git_ok(source, {"push", "--quiet", "envelope",
      same_head .. ":refs/heads/" .. BRANCH})

  local a_root, b_root, overlap_root = fs.join(tmp, "writer-a"),
  fs.join(tmp, "writer-b"), fs.join(tmp, "writer-overlap")
  assert(writer(a_root, source, envelope) == same_head)
  assert(writer(b_root, source, envelope) == same_head)
  assert(writer(overlap_root, source, envelope) == same_head)
  local a1 = commit(a_root, "writer a", a0)
  local b1 = commit(b_root, "writer b", b0)
  local overlap1 = commit(overlap_root, "writer overlap", a0)
  local a_change, b_change, overlap_change = update(A_REF, a0, a1),
  update(B_REF, b0, b1), update(A_REF, a0, overlap1)
  local a_plan = check.must(build(a_root, same_head, "writer-a", a_change))
  local b_plan = check.must(build(b_root, same_head, "writer-b", b_change))
  local overlap_plan = check.must(build(overlap_root, same_head,
      "writer-overlap", overlap_change))
  assert(a_plan.expected_head == b_plan.expected_head
    and b_plan.expected_head == overlap_plan.expected_head,
    "all writers must freeze the same exact envelope head")
  local a_candidate = check.must(plans.local_candidate(a_root, a_plan))
  local b_sibling = check.must(plans.local_candidate(b_root, b_plan))
  local overlap_sibling = check.must(plans.local_candidate(overlap_root, overlap_plan))
  assert(push(a_root, a_candidate))
  local rejected, berr = push(b_root, b_sibling)
  assert(rejected == nil and berr ~= "", "a sibling commit must fail a non-forced push")
  rejected, berr = push(overlap_root, overlap_sibling)
  assert(rejected == nil and berr ~= "", "an overlapping sibling must also fail")
  assert(git_ok(envelope, {"rev-parse", "refs/heads/" .. BRANCH}) == a_candidate,
    "rejected siblings cannot move the envelope ref")

  git_ok(b_root, {"fetch", "--quiet", "envelope",
      "+refs/heads/" .. BRANCH .. ":refs/remotes/envelope/" .. BRANCH})
  local observed = git_ok(b_root, {"rev-parse", "refs/remotes/envelope/" .. BRANCH})
  assert(observed == a_candidate)
  local b_retry = check.must(build(b_root, observed, "writer-b", b_change))
  assert(b_retry.transaction == b_plan.transaction
    and b_retry.transaction_sha == b_plan.transaction_sha,
    "a disjoint retry must preserve the original transaction identity")
  local b_candidate = check.must(plans.local_candidate(b_root, b_retry))
  assert(push(b_root, b_candidate))

  git_ok(overlap_root, {"fetch", "--quiet", "envelope",
      "+refs/heads/" .. BRANCH .. ":refs/remotes/envelope/" .. BRANCH})
  -- The exact winner object remains addressable even though the disjoint
  -- retry has since advanced the branch beyond it.
  local lost, lost_err = build(overlap_root, a_candidate,
    "writer-overlap", overlap_change)
  assert(lost == nil and lost_err == "LOST_RACE: " .. A_REF,
    "an overlapping retry must refuse its stale logical lease: " .. lost_err)
  local final = check.must(plans.inspect_head(b_root, b_candidate, b_retry))
  assert(final.refs[A_REF] == a1 and final.refs[B_REF] == b1,
    "the serialized winners must retain both disjoint logical updates")
  assert(final.publication_status == "confirmed",
    "the final archive must carry the exact retried transaction receipt")
  local reused, reuse_err = build(b_root, b_candidate, "writer-a", b_change)
  assert(reused == nil and reuse_err:find("reused for different contents", 1, true),
    "a committed transaction ID must stay bound to its original contents: " .. reuse_err)
end
test_nonforced_races_retry_only_disjoint_original_transaction()

print("singlehead_plan_test: ok")
