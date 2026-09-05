#!/usr/bin/env cosmic
-- The state verbs against scratch state repositories: `take`, `drop` and `done`, their
-- refusals, and the properties that hold across one mutation — one commit per item it
-- touches, a spec bar and a doing bound that bind the take of NEW work only, and a drop
-- that clears every lock together. What the sidecar itself has to say for an item to be
-- taken is `_work/gitspec_test.tl`; `take --pr`'s own tests are
-- `_work/gitverbs_pr_test.tl`, split out to stay under the file's line cap.

local check = require("cosmic.check")
local child = require("cosmic.child")
local flow = require("_work.flow")
local item = require("_work.item")
local publish = require("_work.publish")
local read = require("_work.read")
local store = require("_work.store")
local fixture = require("_work.fixture")
local gate = require("_work.gitgate")
local gitsync = require("_work.gitsync")
local spec = require("_work.spec")
local storewrite = require("_work.storewrite")
local verbs = require("_work.gitverbs")
local graph = require("_work.gitgraph")
local vrd = require("_work.gitverdict")

local init_state_repo = fixture.init_state_repo
local init_shared = fixture.init_shared
local file_item = fixture.file_item
local commits = fixture.commits
local give_spec = fixture.give_spec
local root_with_leaf = fixture.root_with_leaf

-- The take of todo work is the pull, and it is where the spec bar binds: an item whose
-- sidecar misses a section is refused, refined, then taken. Its success line also names
-- the branch to check out, off the repo's own default base.
local function test_take_asks_the_spec_bar_of_todo_work()
  local s = init_state_repo("bar")
  local _, leaf = root_with_leaf(s)
  assert(verbs.cmd_take(s, leaf, "session-a", 0, false, "") ~= 0,
    "an unrefined spec is refused at take")
  assert(check.must(store.load(s, leaf)).claim == "", "and nothing is written")
  give_spec(s, leaf)
  local before, seen, old_print = commits(s), "", _G.print
  _G.print = function(msg: any) seen = tostring(msg) end
  assert(verbs.cmd_take(s, leaf, "session-a", 0, false, "") == 0,
    "a spec passing the bar is taken")
  _G.print = old_print
  assert(commits(s) == before + 1, "one mutation, one commit")
  assert(seen == ("gitboard-take: %s is yours — branch %s off main"):format(leaf:sub(1, 8), leaf:sub(1, 8)), seen)
  local taken = check.must(store.load(s, leaf))
  assert(taken.claim == "session-a", "the claim is the lock")
  assert(#taken.builders == 1 and taken.builders[1] == "session-a",
    "and the builder is on the record")
  local _, cosmop = root_with_leaf(s)
  give_spec(s, cosmop)
  assert(graph.cmd_set(s, cosmop, nil, "cosmic-lua/cosmopolitan", nil) == 0)
  seen, old_print = "", _G.print
  _G.print = function(msg: any) seen = tostring(msg) end
  assert(verbs.cmd_take(s, cosmop, "session-b", 0, false, "") == 0)
  _G.print = old_print
  assert(seen == ("gitboard-take: %s is yours — branch %s off master"):format(cosmop:sub(1, 8), cosmop:sub(1, 8)), seen)
end

-- The incident, refused at the door: a mangled argv absorbing a literal `--session` as the
-- identity can no longer enter the claim, the builders list, or — via the review-claim
-- derivation — the reviewer field.
local function test_take_refuses_a_flag_shaped_session()
  local s = init_state_repo("flagsession")
  local _, leaf = root_with_leaf(s)
  give_spec(s, leaf)
  assert(verbs.cmd_take(s, leaf, "--session", 0, false, "") ~= 0,
    "a flag-shaped claim is refused")
  local it = check.must(store.load(s, leaf))
  assert(it.claim == "" and #it.builders == 0, "and nothing is written")
  -- The review claim runs through the same gate: hand the build over
  -- as a real session, then offer the review to a flag-shaped one.
  assert(verbs.cmd_take(s, leaf, "builder-a", 0, false, "") == 0)
  assert(verbs.cmd_take(s, leaf, "builder-a", 7, false, "") == 0)
  assert(verbs.cmd_take(s, leaf, "--force", 0, false, "") ~= 0,
    "a flag-shaped reviewer is refused")
  assert(check.must(store.load(s, leaf)).reviewer == "", "and no reviewer is recorded")
end

-- Work under an unranked root is refused at take: rank is a path from
-- the root, and a root nothing has ranked cannot be queued honestly.
local function test_take_refuses_work_under_an_unranked_root()
  local s = init_state_repo("unranked")
  local capture = file_item(s, "an unranked root", "")
  local kid = file_item(s, "its child", capture)
  give_spec(s, kid)
  assert(verbs.cmd_take(s, kid, "session-a", 0, false, "") ~= 0,
    "work under an unranked root has no rank path")
end

-- A `blocked_by` edge never refuses a take: it is an edge kind this
-- build does not interpret, hand-written straight through
-- `storewrite.save` — no verb writes it any more — and the rank path
-- is the whole of the queue and the gate now, so an edge recorded on
-- the item is not part of it.
local function test_take_is_never_refused_by_an_open_blocker()
  local s = init_state_repo("blocked")
  local goal, leaf = root_with_leaf(s)
  local blocker = file_item(s, "lands first", goal)
  give_spec(s, leaf)
  local it = check.must(store.load(s, leaf))
  it.other_edges = {blocked_by = {[blocker] = ""}}
  assert(storewrite.save(s, it, "hand-edited blocked_by"))
  assert(verbs.cmd_take(s, leaf, "session-a", 0, false, "") == 0,
    "an open blocker never gates the take")
  local reloaded_edges = check.must(store.load(s, leaf)).other_edges
  assert(reloaded_edges ~= nil and reloaded_edges.blocked_by[blocker] == "",
    "the edge still stands untouched")
end

-- The doing bound binds NEW takes only: at the limit a take of todo
-- work is refused, while a re-take of in-flight work is not.
local function test_the_bound_refuses_new_takes_not_retakes()
  local s = init_state_repo("bound")
  local goal, leaf = root_with_leaf(s)
  give_spec(s, leaf)
  assert(verbs.cmd_take(s, leaf, "session-a", 0, false, "") == 0)
  for k = 2, flow.DOING_LIMIT do
    local id = file_item(s, ("slice %d"):format(k), goal)
    give_spec(s, id)
    assert(verbs.cmd_take(s, id, ("wake-%d"):format(k), 0, false, "") == 0)
  end
  local extra = file_item(s, "one too many", goal)
  give_spec(s, extra)
  assert(verbs.cmd_take(s, extra, "session-b", 0, false, "") ~= 0,
    "doing is at its bound: the new take queues")
  assert(check.must(store.load(s, extra)).claim == "", "and stays todo")
  assert(verbs.cmd_take(s, leaf, "session-a", 0, false, "") == 0,
    "re-taking your own in-flight work adds nothing and is admitted")
end

-- A claim is a lease: a live foreign claim refuses a take without
-- force, and the builder's own re-take is free.
local function test_a_live_foreign_claim_holds()
  local s = init_state_repo("lease")
  local _, leaf = root_with_leaf(s)
  give_spec(s, leaf)
  assert(verbs.cmd_take(s, leaf, "session-a", 0, false, "") == 0)
  assert(verbs.cmd_take(s, leaf, "session-b", 0, false, "") ~= 0,
    "a live claim is another builder mid loop")
  assert(check.must(store.load(s, leaf)).claim == "session-a", "and holds")
  assert(verbs.cmd_take(s, leaf, "session-b", 0, true,
      "the builder's session died mid-slice") == 0,
    "a takeover says so with --force --why")
  local taken = check.must(store.load(s, leaf))
  assert(taken.claim == "session-b", "the claim moved")
  assert(#taken.builders == 2, "and both holders are on the record")
end

-- A drop names its reason, clears every lock together, and is never
-- refused for flow — leftward motion is the system correcting itself.
local function test_drop_clears_the_locks_and_names_the_reason()
  local s = init_state_repo("drop")
  local _, leaf = root_with_leaf(s)
  give_spec(s, leaf)
  assert(verbs.cmd_take(s, leaf, "session-a", 0, false, "") == 0)
  assert(verbs.cmd_take(s, leaf, "session-a", 77, false, "") == 0)
  assert(verbs.cmd_drop(s, leaf, "session-a", "", false) ~= 0,
    "a drop with no reason named is refused")
  assert(verbs.cmd_drop(s, leaf, "session-a",
      "session out of budget mid-slice", false) == 0)
  local dropped = check.must(store.load(s, leaf))
  assert(dropped.claim == "" and dropped.pr == 0 and dropped.verdict == "",
    "the claim, the PR and any verdict clear together")
  check.must(store.list(s))
  local dc = check.must(store.read(s))
  assert(check.must(read.state(dc, dropped.id)) == "todo",
    "the item is todo again")
  local events = check.must(publish.history(s, leaf))
  assert(events[1].subject:find("out of budget", 1, true),
    "the reason is in the log: " .. events[1].subject)
  assert(verbs.cmd_drop(s, leaf, "session-a", "again", false) ~= 0,
    "dropping what is not in flight is a typo, not a mutation")
end

-- Verdicts before new work, mechanically: a todo pull is refused while an unclaimed diff
-- the session could review awaits a verdict. The review claim itself is a finishing motion
-- the gate never refuses, a recorded reviewer clears the debt, and the item's own builder
-- — who could not give the verdict — is never held back by it.
local function test_take_refuses_a_pull_past_an_unclaimed_verdict()
  local s = init_state_repo("review-debt")
  local goal, built = root_with_leaf(s)
  local second = file_item(s, "the next slice", goal)
  give_spec(s, built)
  give_spec(s, second)
  assert(verbs.cmd_take(s, built, "session-a", 0, false, "") == 0)
  assert(verbs.cmd_take(s, built, "session-a", 77, false, "") == 0,
    "the handover records the PR")
  local all = check.must(store.list(s))
  local c = check.must(store.read(s))
  assert(#check.must(gate.review_debt(c, all, "session-b")) == 1,
    "the unclaimed verdict is session-b's debt")
  assert(#check.must(gate.review_debt(c, all, "session-a")) == 0,
    "the builder could not give the verdict, so it is not their debt")
  assert(verbs.cmd_take(s, second, "session-b", 0, false, "") ~= 0,
    "a pull past the waiting verdict is refused")
  assert(check.must(store.load(s, second)).claim == "",
    "and the refused pull claimed nothing")
  assert(verbs.cmd_take(s, built, "session-b", 0, false, "") == 0,
    "the review claim itself is a finishing motion, never refused")
  assert(verbs.cmd_take(s, second, "session-c", 0, false, "") == 0,
    "a recorded reviewer clears the debt and the queue moves again")
end

-- A drop returns the lease and touches nothing else: a blocker edge
-- hand-wired mid-build survives the drop untouched, since this verb
-- clears claims and verdicts, never the item's other fields.
local function test_drop_leaves_blockers_standing()
  local s = init_state_repo("drop-blocked")
  local goal, leaf = root_with_leaf(s)
  give_spec(s, leaf)
  assert(verbs.cmd_take(s, leaf, "session-a", 0, false, "") == 0)
  local question = file_item(s, "which premise still holds?", goal)
  local it = check.must(store.load(s, leaf))
  it.other_edges = {blocked_by = {[question] = ""}}
  assert(storewrite.save(s, it, "hand-edited blocked_by"))
  -- Straight through `storewrite.save`, bypassing the cache patch AND
  -- the lease `commit_and_publish` would otherwise have refreshed —
  -- closed here so `cmd_drop` below reads a fresh lease rather than
  -- fast-importing against the sha this hand-edit already moved past.
  local _cok, _cerr = store.close(s)
  assert(verbs.cmd_drop(s, leaf, "session-a",
      "blocked on the question", false) == 0)
  local dropped = check.must(store.load(s, leaf))
  assert(dropped.claim == "", "the lease returned")
  local dropped_edges = dropped.other_edges
  assert(dropped_edges ~= nil and dropped_edges.blocked_by[question] == "",
    "the blocker edge survives the drop untouched")
end

-- Another session's live claim refuses a drop without force: the
-- builder may be mid loop on a machine the board cannot see.
local function test_a_foreign_drop_needs_force()
  local s = init_state_repo("abandon")
  local _, leaf = root_with_leaf(s)
  give_spec(s, leaf)
  assert(verbs.cmd_take(s, leaf, "session-a", 0, false, "") == 0)
  assert(verbs.cmd_drop(s, leaf, "session-b", "looks dead to me",
      false) ~= 0,
    "another session cannot silently abandon a live claim")
  assert(check.must(store.load(s, leaf)).claim == "session-a", "it holds")
  assert(verbs.cmd_drop(s, leaf, "session-b",
      "the builder's session died mid-slice", true) == 0,
    "a forced abandon with the gap named goes through")
end

-- `done` under an unjudged PR is refused: the diff still exists on GitHub, and ending the
-- item makes it vanish from the board. Claimed no-PR work is evidence mid-review the same
-- way — an item nobody ever claimed carries no such claim of success, and ends freely, but
-- a claimant's research slice needs its accept the same as a diff does; `--force --why`
-- remains the repair for ending one nothing will ever review (an obsolete slice, a
-- duplicate).
local function test_done_guards_an_unjudged_pr()
  local s = init_state_repo("done-guard")
  local goal, leaf = root_with_leaf(s)
  give_spec(s, leaf)
  assert(verbs.cmd_take(s, leaf, "session-a", 0, false, "") == 0)
  assert(verbs.cmd_take(s, leaf, "session-a", 99, false, "") == 0)
  assert(verbs.cmd_done(s, leaf, "completed", false, "") ~= 0,
    "an unjudged PR holds the item open")
  assert(verbs.cmd_done(s, leaf, "completed", true,
      "the PR was closed by hand") == 0,
    "--force --why is the repair path")
  local other = file_item(s, "a research slice", goal)
  give_spec(s, other)
  assert(verbs.cmd_take(s, other, "session-a", 0, false, "") == 0)
  assert(verbs.cmd_done(s, other, "completed", false, "") ~= 0,
    "claimed no-PR work with no accept holds the item open too")
  assert(vrd.cmd_verdict(s, other, "accept", 0, "", "reviewer-a") == 0,
    "an evidence-only item takes a verdict too — no --head needed")
  assert(verbs.cmd_done(s, other, "completed", false, "") == 0,
    "an accept clears the way")
  local ended = check.must(store.load(s, other))
  assert(ended.claim == "", "and done clears the claim")
  local dup = file_item(s, "a duplicate of the slice above", goal)
  give_spec(s, dup)
  assert(verbs.cmd_take(s, dup, "session-a", 0, false, "") == 0)
  assert(verbs.cmd_done(s, dup, "completed", true,
      "duplicate of the research slice above") == 0,
    "--force --why still ends an item nothing will ever review")
end

-- `drop` clears the live claim but never touches `builders` — the append-only record of
-- every session that ever held it — so the PR-less done gate above must key on that
-- history, not the live claim. Keying on the live claim let take -> drop -> done slip a
-- worked research item past review with no verdict and no --force: the exact bypass this
-- test pins shut.
local function test_done_guards_a_dropped_items_worked_history()
  local s = init_state_repo("drop-then-done")
  local _, leaf = root_with_leaf(s)
  give_spec(s, leaf)
  assert(verbs.cmd_take(s, leaf, "session-a", 0, false, "") == 0)
  assert(verbs.cmd_drop(s, leaf, "session-a",
      "pausing to rethink the approach", false) == 0)
  local dropped = check.must(store.load(s, leaf))
  assert(dropped.claim == "" and #dropped.builders == 1,
    "the claim clears but the builders record survives the drop")
  assert(verbs.cmd_done(s, leaf, "completed", false, "") ~= 0,
    "a dropped item with worked history still owes a verdict")
  assert(verbs.cmd_done(s, leaf, "completed", true,
      "abandoning this line of research") == 0,
    "--force --why remains the repair path")
  local ended = check.must(store.load(s, leaf))
  assert(ended.claim == "", "and done clears the claim")
end

-- Closing the last child makes the container workable again by derivation — nothing is
-- written to it, and the verdict line says what to do with it.
local function test_done_says_when_a_container_is_workable_again()
  local s = init_state_repo("return")
  local _, leaf = root_with_leaf(s)
  local kid = file_item(s, "only child", leaf)
  local before = commits(s)
  assert(verbs.cmd_done(s, kid, "completed", false, "") == 0)
  assert(commits(s) == before + 1, "the close is one commit")
  local all = check.must(store.list(s))
  local c = check.must(store.read(s))
  local parent = item.by_id(all)[leaf]
  assert(check.must(read.role(c, parent.id)) == "work",
    "its last child closed, so the container is workable by derivation")
  local structure = check.must(read.structure(c))
  local details: {string} = {}
  for _, p in ipairs(structure) do
    details[#details + 1] = ("%s: %s"):format(p.id, p.detail)
  end
  assert(#structure == 0,
    "and nothing is left off the board: " .. table.concat(details, "; "))
end

-- The already-recorded case: `done` again with the same reason is a no-op that succeeds.
-- `not-planned`: this lone root has no completed child to name as `--by`
-- evidence, and `completed` on a root now requires one.
local function test_done_again_is_a_noop_success()
  local s = init_state_repo("done-noop")
  local id = file_item(s, "a lone item", "")
  assert(verbs.cmd_done(s, id, "not-planned", false, "") == 0)
  local before, seen, old_print = commits(s), "", _G.print
  _G.print = function(msg: any) seen = tostring(msg) end
  local again = verbs.cmd_done(s, id, "not-planned", false, "")
  _G.print = old_print
  assert(again == 0 and commits(s) == before
    and seen:find("nothing to record", 1, true) ~= nil, seen)
end

-- --force is for repair, and a repair the log cannot explain is
-- indistinguishable from ordinary flow.
local function test_force_states_its_reason_and_the_log_keeps_it()
  local s = init_state_repo("why")
  local _, leaf = root_with_leaf(s)
  give_spec(s, leaf)
  assert(verbs.cmd_take(s, leaf, "session-a", 0, true, "") ~= 0,
    "a bare --force is refused")
  assert(check.must(store.load(s, leaf)).claim == "", "and changes nothing")
  assert(verbs.cmd_take(s, leaf, "session-a", 0, true,
      "repairing a claim the importer mangled") == 0)
  local events = check.must(publish.history(s, leaf))
  assert(events[1].subject:find("forced: repairing a claim", 1, true),
    "the reason rides the commit: " .. events[1].subject)
end

-- A take of NEW work is bounded — it advances and leases
-- `refs/heads/board/seq`, the same protection the doing bound needs — so
-- two takes of two DIFFERENT items still race each other on that one
-- shared ref, even though each writes its own item's ref independently.
-- The loser is refused with LOST_RACE and lands on the re-run against
-- the merged state, leaving the checkout clean.
local function test_a_take_survives_a_lost_race()
  local a, b = init_shared("take-race")
  local goal, leaf = root_with_leaf(a)
  give_spec(a, leaf)
  local other = file_item(a, "another workable slice", goal)
  give_spec(a, other)
  assert(publish.sync(b))
  -- b's take of a DIFFERENT item is the first to advance
  -- refs/heads/board/seq, so a's take below — decided before it saw that —
  -- loses the lease it never knew had moved.
  assert(verbs.cmd_take(b, other, "session-b", 0, false, "") == 0)
  assert(verbs.cmd_take(a, leaf, "session-a", 0, false, "") ~= 0,
    "the stale run is refused, not replayed")
  assert(verbs.cmd_take(a, leaf, "session-a", 0, false, "") == 0,
    "the re-run lands against the merged board")
  local r = check.must(child.run({"git", "status", "--porcelain"},
      {cwd = a.root}))
  -- `o/` is the cache database `_work.cache` just built reading this
  -- board — an expected, gitignored-in-a-real-checkout artifact, never
  -- a mutation touching the working tree; every OTHER line still has
  -- to be empty.
  local stray: {string} = {}
  for line in (r.stdout or ""):gmatch("[^\n]+") do
    if line:match("^%?%? o/") == nil then
      stray[#stray + 1] = line
    end
  end
  assert(#stray == 0,
    "the mutation leaves no stray change: " .. table.concat(stray, "\n"))
end

-- sync rebases and then asks about lane health; a local-only checkout has no origin, so
-- lane health comes back unknown rather than red, and sync itself still succeeds — the
-- same shape a token-less or offline session sees. `_work.lanes_test` drives
-- `observe`/`record`/`mint` directly; this pins that `_work.gitsync.cmd_sync` reaches
-- them at all.
local function test_sync_asks_about_lanes_and_survives_not_knowing()
  local s = init_state_repo("sync-lanes")
  assert(gitsync.cmd_sync(s) == 0, "an unknown lane state does not fail sync")
end

-- `take --result` is the research handover, `take --pr`'s mirror for an item whose
-- deliverable is the spec: the claim holder's own motion, so it needs the live claim and
-- nothing else; it records the sidecar's revision and the item awaits a verdict from then
-- on — the review claim derives for it as for a PR, and a drop clears it with the claim —
-- and the two handovers exclude each other both ways.
local function test_take_result_records_the_research_handover()
  local s = init_state_repo("result")
  local _, leaf = root_with_leaf(s)
  give_spec(s, leaf)
  assert(verbs.cmd_take(s, leaf, "session-a", 0, false, "", true) ~= 0,
    "unclaimed: nothing to hand over")
  assert(check.must(store.load(s, leaf)).claim == "", "and nothing is written")
  assert(verbs.cmd_take(s, leaf, "session-a", 0, false, "") == 0)
  assert(verbs.cmd_take(s, leaf, "session-b", 0, false, "", true) ~= 0,
    "another session's claim is not yours to hand over")
  assert(verbs.cmd_take(s, leaf, "session-a", 5, false, "", true) ~= 0,
    "--pr and --result together are refused")
  local before = commits(s)
  assert(verbs.cmd_take(s, leaf, "session-a", 0, false, "", true) == 0,
    "the claim holder hands over")
  assert(commits(s) == before + 1, "one mutation, one commit")
  local handed = check.must(store.load(s, leaf))
  assert(handed.result == spec.revision(store.read_spec(s, leaf)),
    "the handover records the spec's revision")
  assert(handed.claim == "session-a", "the claim survives it")
  check.must(store.list(s))
  local hc = check.must(store.read(s))
  assert(check.must(read.substate(hc, handed.id)) == "review",
    "and the item awaits a verdict")
  assert(verbs.cmd_take(s, leaf, "session-a", 0, false, "", true) == 0,
    "re-handing the same spec over is a no-op")
  assert(commits(s) == before + 1, "nothing new to commit")
  assert(verbs.cmd_take(s, leaf, "session-a", 7, false, "") ~= 0,
    "--pr on a research handover is refused")
  assert(check.must(store.load(s, leaf)).pr == 0, "and records nothing")
  assert(verbs.cmd_take(s, leaf, "session-b", 0, false, "") == 0,
    "another session's take is the review claim, as for a PR")
  assert(check.must(store.load(s, leaf)).reviewer == "session-b",
    "and the review lock is theirs")
  assert(vrd.cmd_verdict(s, leaf, "accept", 0, "", "session-b") == 0)
  local judged = commits(s)
  assert(verbs.cmd_take(s, leaf, "session-a", 0, false, "", true) == 0,
    "the same spec over a standing accept is a no-op, as a repeated --pr is")
  assert(commits(s) == judged, "nothing new to commit")
  assert(check.must(store.load(s, leaf)).verdict == "accept",
    "and the accept survives the re-run")
  assert(verbs.cmd_drop(s, leaf, "session-a", "out of budget", false) == 0)
  assert(check.must(store.load(s, leaf)).result == "",
    "a drop clears the handover with the claim")
  local _, other = root_with_leaf(s)
  give_spec(s, other)
  assert(verbs.cmd_take(s, other, "session-c", 0, false, "") == 0)
  assert(verbs.cmd_take(s, other, "session-c", 8, false, "") == 0)
  assert(verbs.cmd_take(s, other, "session-c", 0, false, "", true) ~= 0,
    "--result on an item carrying a PR is refused")
  assert(check.must(store.load(s, other)).result == "", "and records nothing")
end
