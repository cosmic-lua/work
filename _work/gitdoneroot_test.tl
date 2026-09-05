#!/usr/bin/env cosmic
-- A verified root is `done --reason completed --by CHILD`, where CHILD is a completed
-- child carrying the evidence: `_work/gitdoneroot.tl` is the gate, called from
-- `_work.gitverbs.cmd_done`. `not-planned` needs no evidence, and `--by` off a root is
-- meaningless. Filing or attaching a child under a done root reopens it in the same
-- commit (`gate.containered`, `_work/gitgate_test.tl` covers the marker-clearing half).

local check = require("cosmic.check")
local fixture = require("_work.fixture")
local graph = require("_work.gitgraph")
local publish = require("_work.publish")
local store = require("_work.store")
local verbs = require("_work.gitverbs")

local init_state_repo = fixture.init_state_repo
local file_item = fixture.file_item
local commits = fixture.commits

-- A root's win condition, verified: the completed child's id names the evidence, in
-- both the verdict line and the commit subject.
local function test_done_by_a_completed_child_verifies_the_root()
  local s = init_state_repo("done-by")
  local root = file_item(s, "an outcome", "")
  local evidence = file_item(s, "the observable test passed", root)
  assert(verbs.cmd_done(s, evidence, "completed", false, "") == 0)
  local seen, old_print = "", _G.print
  _G.print = function(msg: any) seen = tostring(msg) end
  local ok = verbs.cmd_done(s, root, "completed", false, "", evidence)
  _G.print = old_print
  assert(ok == 0, seen)
  assert(seen:find(evidence:sub(1, 8), 1, true) ~= nil,
    "the verdict line names the evidence: " .. seen)
  local done = check.must(store.load(s, root))
  assert(done.resolution == "completed", "the root is done")
  local events = check.must(publish.history(s, root))
  assert(events[1].subject:find(evidence:sub(1, 8), 1, true) ~= nil,
    "the commit subject names the evidence too: " .. events[1].subject)
end

-- A missing `--by` refuses `completed` on a root outright.
local function test_completed_without_by_is_refused()
  local s = init_state_repo("done-no-by")
  local root = file_item(s, "an outcome", "")
  local evidence = file_item(s, "the observable test passed", root)
  assert(verbs.cmd_done(s, evidence, "completed", false, "") == 0)
  assert(verbs.cmd_done(s, root, "completed", false, "") ~= 0,
    "completed on a root names its evidence")
  assert(check.must(store.load(s, root)).resolution == "",
    "and the refusal writes nothing")
end

-- A `--by` that names some OTHER item entirely (not this root's child at all) is refused.
local function test_by_naming_a_stranger_is_refused()
  local s = init_state_repo("done-by-stranger")
  local root = file_item(s, "an outcome", "")
  local stranger = file_item(s, "an unrelated capture", "")
  assert(verbs.cmd_done(s, root, "completed", false, "", stranger) ~= 0,
    "a stranger is not this root's child")
  assert(check.must(store.load(s, root)).resolution == "",
    "and nothing was written")
end

-- A `--by` naming a child of a DIFFERENT root is refused: the evidence has to belong
-- to the outcome it verifies.
local function test_by_naming_another_roots_child_is_refused()
  local s = init_state_repo("done-by-cousin")
  local root_a = file_item(s, "outcome A", "")
  local root_b = file_item(s, "outcome B", "")
  local cousin = file_item(s, "B's evidence", root_b)
  assert(verbs.cmd_done(s, cousin, "completed", false, "") == 0)
  assert(verbs.cmd_done(s, root_a, "completed", false, "", cousin) ~= 0,
    "B's child is not A's evidence")
  assert(check.must(store.load(s, root_a)).resolution == "",
    "and A stays open")
end

-- A `--by` naming a CLOSED child whose own resolution is not "completed" (a
-- not-planned sibling, say) is refused: it carries no open child either, so this
-- isolates the completed-check from the open-child check below.
local function test_by_naming_an_uncompleted_child_is_refused()
  local s = init_state_repo("done-by-uncompleted-child")
  local root = file_item(s, "an outcome", "")
  local kid = file_item(s, "abandoned, not verified", root)
  assert(verbs.cmd_done(s, kid, "not-planned", false, "") == 0)
  assert(verbs.cmd_done(s, root, "completed", false, "", kid) ~= 0,
    "a not-planned child is not completed evidence")
  assert(check.must(store.load(s, root)).resolution == "",
    "and nothing was written")
end

-- An open child remaining anywhere under the root refuses `done`, even when the
-- named `--by` child is itself completed: a verified outcome has NO open work left.
local function test_an_open_child_remaining_refuses_done()
  local s = init_state_repo("done-open-sibling")
  local root = file_item(s, "an outcome", "")
  local evidence = file_item(s, "the observable test passed", root)
  local sibling = file_item(s, "still building", root)
  assert(verbs.cmd_done(s, evidence, "completed", false, "") == 0)
  assert(verbs.cmd_done(s, root, "completed", false, "", evidence) ~= 0,
    "sibling is still open")
  assert(check.must(store.load(s, root)).resolution == "",
    "and the root stays open")
  assert(verbs.cmd_done(s, sibling, "not-planned", false, "") == 0)
  assert(verbs.cmd_done(s, root, "completed", false, "", evidence) == 0,
    "no open child remains, so the same evidence now verifies it")
end

-- Retiring a root asks only for the reason: `not-planned` needs no `--by`, and passing
-- one anyway is refused — it would record evidence a retired outcome never had.
local function test_not_planned_needs_no_by_and_refuses_one()
  local s = init_state_repo("done-not-planned")
  local root = file_item(s, "a capture nobody will build", "")
  assert(verbs.cmd_done(s, root, "not-planned", false, "") == 0,
    "not-planned asks only for the reason")
  local retired = check.must(store.load(s, root))
  assert(retired.resolution == "not-planned", "the root is retired")

  local root2 = file_item(s, "another capture", "")
  local evidence = file_item(s, "irrelevant here", root2)
  assert(verbs.cmd_done(s, evidence, "completed", false, "") == 0)
  assert(verbs.cmd_done(s, root2, "not-planned", false, "", evidence) ~= 0,
    "--by names evidence a retired outcome never had")
  assert(check.must(store.load(s, root2)).resolution == "",
    "and the refusal writes nothing")
end

-- `--by` off a root names nothing and is refused, whichever reason is given.
local function test_by_off_a_root_is_meaningless()
  local s = init_state_repo("done-by-non-root")
  local root, leaf = fixture.root_with_leaf(s)
  local other = file_item(s, "some other item", root)
  assert(verbs.cmd_done(s, leaf, "completed", false, "", other) ~= 0,
    "--by is a root's own gate, not a parented item's")
  assert(check.must(store.load(s, leaf)).resolution == "",
    "and nothing was written")
  -- The regression: a non-root's `done` with no `--by` is unchanged.
  assert(verbs.cmd_done(s, leaf, "completed", false, "") == 0,
    "an ordinary leaf still ends exactly as before")
  assert(check.must(store.load(s, leaf)).resolution == "completed")
end

-- Filing a child under a done root reopens it in the SAME commit as the child —
-- `gate.containered`, wired through `cmd_new`'s decomposition path.
local function test_new_parent_under_a_done_root_reopens_it()
  local s = init_state_repo("reopen-new")
  local root = file_item(s, "an outcome, later reopened", "")
  assert(verbs.cmd_done(s, root, "not-planned", false, "") == 0)
  assert(check.must(store.load(s, root)).resolution == "not-planned")
  local before = commits(s)
  assert(graph.cmd_new(s, "evidence it did not hold after all", root, nil, "") == 0)
  assert(commits(s) == before + 2,
    ("the child and the reopened root land as one push, two commits: %d -> %d")
    :format(before, commits(s)))
  assert(check.must(store.load(s, root)).resolution == "",
    "filing a child under a done root clears its resolution")
end

-- `attach` reopens a done root the same way `new --parent` does.
local function test_attach_under_a_done_root_reopens_it()
  local s = init_state_repo("reopen-attach")
  local root = file_item(s, "an outcome, later reopened by attach", "")
  local evidence = file_item(s, "verified", root)
  assert(verbs.cmd_done(s, evidence, "completed", false, "") == 0)
  assert(verbs.cmd_done(s, root, "completed", false, "", evidence) == 0)
  assert(check.must(store.load(s, root)).resolution == "completed")
  local wanderer = file_item(s, "a capture, moved under the done root", "")
  local before = commits(s)
  assert(graph.cmd_attach(s, wanderer, root) == 0)
  assert(commits(s) == before + 2,
    ("the moved item and the reopened root land as one push: %d -> %d")
    :format(before, commits(s)))
  assert(check.must(store.load(s, root)).resolution == "",
    "attaching a child under a done root clears its resolution")
end
