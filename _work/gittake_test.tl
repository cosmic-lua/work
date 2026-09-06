#!/usr/bin/env cosmic
-- `take_review`'s mutual exclusion is exact-string equality against
-- `it.reviewer` (`_work.gittake`) — correct whenever two sessions'
-- labels genuinely differ, which is what minting `<kind>-<handle>-
-- <orch8>` (`_work.brief.mint_label`) guarantees across two different
-- physical orchestrator sessions, where a bare `<kind>-<handle>-<n>`
-- convention could not: two orchestrators independently computing the
-- identical string read, to this exact-equality check, as one session
-- re-taking its own review — the collision friction-2026-09-04-work9.md
-- measured. Pinned here directly against `gittake`, one level under
-- the `cmd_take` derivation `_work/gitreview_test.tl` already covers.

local cache = require("_work.cache")
local check = require("cosmic.check")
local ciobs = require("_work.ciobs")
local fixture = require("_work.fixture")
local gittake = require("_work.gittake")
local store = require("_work.store")
local storewrite = require("_work.storewrite")
local verbs = require("_work.gitverbs")

local init_state_repo = fixture.init_state_repo
local give_spec = fixture.give_spec
local root_with_leaf = fixture.root_with_leaf

-- Two minted labels for the SAME item's review, sharing everything but
-- the orchestrator's own 8 characters: the second `take_review` is
-- refused at claim time, exactly as two frankly unrelated session
-- names would be — never read as the first session re-taking its own
-- claim.
local function test_labels_differing_only_in_orch8_exclude_each_other()
  local s = init_state_repo("gittake-orch8")
  local _, leaf = root_with_leaf(s)
  give_spec(s, leaf)
  local it = check.must(store.load(s, leaf))
  it.claim = "build-abcd1234-11111111"
  it.pr = 7
  it.builders = {it.claim}
  assert(storewrite.save(s, it, "fixture: handed over for review"))

  local first = "review-abcd1234-aaaaaaaa"
  local second = "review-abcd1234-bbbbbbbb"

  it = check.must(store.load(s, leaf))
  assert(gittake.take_review(s, it, first, false, "") == 0,
    "the first orchestrator's minted label claims the review")
  check.equal(check.must(store.load(s, leaf)).reviewer, first)

  it = check.must(store.load(s, leaf))
  assert(gittake.take_review(s, it, second, false, "") ~= 0,
    "a second orchestrator's label — identical but for orch8 — is "
    .. "refused while the first's claim is live, never read as the "
    .. "same session re-taking")
  check.equal(check.must(store.load(s, leaf)).reviewer, first,
    "and the claim did not move")

  -- The holder's own label, re-offered, is still the idempotent yes
  -- `take_review` always gives a live self-claim.
  it = check.must(store.load(s, leaf))
  assert(gittake.take_review(s, it, first, false, "") == 0,
    "the holder's own exact label re-claims cleanly")
  check.equal(check.must(store.load(s, leaf)).reviewer, first)
end

-- The refusal names the live holder verbatim, so a second orchestrator
-- reading it sees the first's actual label — including its distinct
-- orch8 — rather than a generic "someone else" message.
local function test_the_refusal_names_the_live_labels_orch8()
  local s = init_state_repo("gittake-orch8-refusal")
  local _, leaf = root_with_leaf(s)
  give_spec(s, leaf)
  local it = check.must(store.load(s, leaf))
  it.claim = "build-cafefeed-11111111"
  it.pr = 3
  it.builders = {it.claim}
  assert(storewrite.save(s, it, "fixture: handed over for review"))

  local holder = "review-cafefeed-aaaaaaaa"
  it = check.must(store.load(s, leaf))
  assert(gittake.take_review(s, it, holder, false, "") == 0)

  it = check.must(store.load(s, leaf))
  local old_print = _G.print
  local lines: {string} = {}
  _G.print = function(...: any)
    lines[#lines + 1] = tostring((...))
  end
  local ok, code = pcall(gittake.take_review, s, it,
    "review-cafefeed-bbbbbbbb", false, "")
  _G.print = old_print
  assert(ok, tostring(code))
  assert(code ~= 0, "the takeover is refused with no --force")
  local out = table.concat(lines, "\n")
  assert(out:find("under review by " .. holder, 1, true) ~= nil,
    "the refusal names the exact live label, orch8 included: " .. out)
end

--- Seeds the cache's own `ci_checks` row for `(repo, pr)` directly, the
--- same table `_work.ciobs.record` upserts — bypassing GitHub entirely,
--- exactly what `_work.gitgate.review_debt`'s own CI check reads. The
--- write goes through a connection of its own, outside the patch
--- `_work.gitgate.commit_and_publish` applies to `s`'s already-open
--- index on every ordinary mutation, so `store.close(s)` afterward is
--- this test's stand-in for that patch — the same one `_work/ciobs_test.tl`'s
--- `pr_item` uses — leaving the caller's next `store.list`/`store.read`
--- to reopen fresh instead of missing what this write just made.
--- @param s store.Store The store
--- @param repo string The item's repo field
--- @param pr integer The PR number
--- @param state string The recorded state ("running", "red", ...)
local function seed_ci_state(s: store.Store, repo: string, pr: integer,
    state: string)
  local c = check.must(cache.open(s.root))
  assert(ciobs.record(c, repo, pr, {state = state, head_sha = "", runs = {}}))
  assert(cache.close(c))
  local _cok, _cerr = store.close(s)
end

--- Seeds `built`'s own `items.touched_at` directly, the same direct
--- cache write `seed_ci_state` uses for `ci_checks` — a re-push
--- (which `take --pr` records by moving this) with no real wait for
--- the time this test asks it to have happened. `store.close(s)`
--- afterward is the same stand-in as `seed_ci_state`'s own.
--- @param s store.Store The store
--- @param id string The item's id
--- @param touched_at integer The `items.touched_at` to set
local function seed_touched_at(s: store.Store, id: string, touched_at: integer)
  local c = check.must(cache.open(s.root))
  assert(c.db:exec("UPDATE items SET touched_at = ? WHERE id = ?", {touched_at, id}))
  assert(cache.close(c))
  local _cok, _cerr = store.close(s)
end

--- Seeds `ci_checks` with an explicit `observed_at`, unlike
--- `seed_ci_state`'s own always-now write — so a test can place the
--- recorded observation BEFORE the head it is being compared against,
--- the shape a genuinely stale row actually has.
--- @param s store.Store The store
--- @param repo string The item's repo field
--- @param pr integer The PR number
--- @param state string The recorded state
--- @param observed_at integer The `ci_checks.observed_at` to set
local function seed_ci_state_observed_at(s: store.Store, repo: string, pr: integer,
    state: string, observed_at: integer)
  local c = check.must(cache.open(s.root))
  assert(c.db:exec([[
    INSERT INTO ci_checks(repo, pr, head, state, observed_at) VALUES (?, ?, ?, ?, ?)
    ON CONFLICT(repo, pr) DO UPDATE SET head = excluded.head,
      state = excluded.state, observed_at = excluded.observed_at
  ]], {repo, pr, "", state, observed_at}))
  assert(cache.close(c))
  local _cok, _cerr = store.close(s)
end

-- A todo pull's debt count reads the same recorded CI state the review
-- claim's own live check would find: a diff still `running` has given
-- no verdict to claim yet, so it does not outrank a todo pull, but a
-- diff whose head has settled does — unchanged from before this gate
-- read CI at all.
local function test_running_ci_does_not_block_a_pull_but_a_settled_state_does()
  local s = init_state_repo("gittake-ci-debt")
  local goal, built = root_with_leaf(s)
  local second = fixture.file_item(s, "the next slice", goal)
  give_spec(s, built)
  give_spec(s, second)
  assert(verbs.cmd_take(s, built, "session-a", 0, false, "") == 0)
  assert(verbs.cmd_take(s, built, "session-a", 77, false, "") == 0,
    "the handover records the PR")
  local handed = check.must(store.load(s, built))

  seed_ci_state(s, handed.repo, handed.pr, "running")
  assert(verbs.cmd_take(s, second, "session-b", 0, false, "") == 0,
    "CI still running gives no verdict to claim yet, so it does not "
    .. "outrank the todo pull")
  assert(check.must(store.load(s, second)).claim == "session-b",
    "the pull went through")
  assert(verbs.cmd_drop(s, second, "session-b",
      "reset for the settled-state case", false) == 0)

  seed_ci_state(s, handed.repo, handed.pr, "green")
  assert(verbs.cmd_take(s, second, "session-c", 0, false, "") ~= 0,
    "a settled, non-failing recorded state still outranks the pull")
  assert(check.must(store.load(s, second)).claim == "",
    "and the refused pull claimed nothing")

  -- Concluded failure goes back to the builder, not a reviewer, so it
  -- does not outrank a todo pull either — the same exclusion as a run
  -- still going, for a different reason.
  seed_ci_state(s, handed.repo, handed.pr, "red")
  assert(verbs.cmd_take(s, second, "session-d", 0, false, "") == 0,
    "a concluded failure is the builder's to fix, not a reviewer's "
    .. "verdict to give, so it does not outrank the pull")
  assert(check.must(store.load(s, second)).claim == "session-d",
    "the pull went through")
end

-- A re-push leaves the OLD head's settled verdict sitting in the
-- cache; `ci_clears_debt` must not credit it to the head now under
-- review. Whether the gap counts as debt turns only on how long ago
-- the push (`items.touched_at`) happened: recent enough and it reads
-- as CI still running (a push always starts one, and the cache has
-- not caught up); old enough and it reads as unobserved debt, exactly
-- as if nothing had ever been recorded.
local function test_a_stale_head_observation_falls_back_on_touched_at_recency()
  local s = init_state_repo("gittake-ci-stale-head")
  local goal, built = root_with_leaf(s)
  local second = fixture.file_item(s, "the next slice", goal)
  give_spec(s, built)
  give_spec(s, second)
  assert(verbs.cmd_take(s, built, "session-a", 0, false, "") == 0)
  assert(verbs.cmd_take(s, built, "session-a", 77, false, "") == 0)
  local handed = check.must(store.load(s, built))

  local now = os.time()
  -- The recorded `green` predates BOTH re-pushes below, so it always
  -- answers for a head this item has since moved past.
  seed_ci_state_observed_at(s, handed.repo, handed.pr, "green", now - 4 * 3600)

  seed_touched_at(s, built, now - 5 * 60)
  assert(verbs.cmd_take(s, second, "session-b", 0, false, "") == 0,
    "a re-push 5 minutes old reads as CI still running, not the stale "
    .. "green left over from the head it replaced")
  assert(check.must(store.load(s, second)).claim == "session-b",
    "the pull went through")
  assert(verbs.cmd_drop(s, second, "session-b",
      "reset for the older re-push case", false) == 0)

  seed_touched_at(s, built, now - 3600)
  assert(verbs.cmd_take(s, second, "session-c", 0, false, "") ~= 0,
    "a re-push an hour old is past the cache-lag window — the stale "
    .. "green counts as unobserved debt, outranking the pull")
  assert(check.must(store.load(s, second)).claim == "",
    "and the refused pull claimed nothing")
end
