#!/usr/bin/env cosmic
-- `_work.ciobs`'s caching contract: a fresh observation is reused
-- without touching GitHub again, a stale one is refreshed and its new
-- state replaces the old, and `GITBOARD_CI_FRESH` forces past the
-- window on every call. `is_candidate` and `at_sync` get their own
-- coverage: the exact set `at_sync` walks, and that it observes a
-- stale candidate once, leaves a fresh one alone, and reports rather
-- than swallows an `observe` failure.

local cache = require("_work.cache")
local cachedb = require("_work.cachedb")
local ciobs = require("_work.ciobs")
local env = require("cosmic.env")
local fixture = require("_work.fixture")
local freshness = require("_work.freshness")
local gh = require("_work.gh")
local item = require("_work.item")
local store = require("_work.store")

local init_state_repo = fixture.init_state_repo
local REPO < const > = "cosmic-lua/cosmic"

--- Stand `gh.head_checks` in for `stub` (a counting stub on the module
--- table, the swap-and-restore `_work/gitview_test.tl`'s `with_ci_state`
--- also uses) for the duration of `f`, restoring the real function even
--- when `f` fails an assertion.
--- @param stub function(s: store.Store, pr: integer, repo: string | nil): gh.HeadChecks | nil, string
--- @param f function(): boolean The test body; returns true when done
local function with_head_checks(stub: function(store.Store, integer, string | nil):
    gh.HeadChecks | nil, string, f: function(): boolean)
    local real = gh.head_checks
    gh.head_checks = stub
    local ok, err = pcall(f)
    gh.head_checks = real
    if not ok then
      error(err, 0)
    end
  end

  --- `read`+`fresh`+`observe` composed exactly as `_work/gitview.tl`'s
  --- `ci_states` composes them: the one render-side pattern this module
  --- exists to make cheap on the second call.
  --- @param s store.Store The store
  --- @param c cachedb.Cache An open cache connection
  --- @param pr integer The PR number
  --- @return string | nil The state a render would show
  local function render(s: store.Store, c: cachedb.Cache, pr: integer): string | nil
    local state, age = ciobs.read(c, REPO, pr)
    if state == nil or not ciobs.fresh(age) then
      state = ciobs.observe(s, c, REPO, pr)
    end
    return state
  end

  -- Two renders inside the window: the second reuses the cached row, so
  -- the stub is called once for both, not once each.
  local function test_two_renders_inside_the_window_make_one_call()
    local s = init_state_repo("ciobs-fresh")
    local c = assert(cache.open(s.root))
    local calls = 0
    with_head_checks(function(_s: store.Store, _pr: integer, _repo: string | nil):
        gh.HeadChecks | nil, string
        calls = calls + 1
        return {state = "green", head_sha = "aaa", runs = {}}, ""
      end, function(): boolean
        assert(render(s, c, 1) == "green")
        assert(render(s, c, 1) == "green")
        assert(calls == 1, "the second render never reaches GitHub: " .. tostring(calls))
        return true
      end)
    assert(cache.close(c))
  end

  -- A row aged past the window is refreshed rather than reused, and the
  -- fresh call's state (and head) replace what was cached — a pushed
  -- head is exactly what ages a row out, since nothing here can learn of
  -- one without spending the live call the window is there to bound.
  local function test_a_stale_observation_is_refreshed_and_replaced()
    local s = init_state_repo("ciobs-stale")
    local c = assert(cache.open(s.root))
    local calls = 0
    with_head_checks(function(_s: store.Store, _pr: integer, _repo: string | nil):
        gh.HeadChecks | nil, string
        calls = calls + 1
        if calls == 1 then
          return {state = "green", head_sha = "aaa", runs = {}}, ""
        end
        return {state = "red", head_sha = "bbb", runs = {}}, ""
      end, function(): boolean
        assert(render(s, c, 2) == "green")
        assert(calls == 1)

        -- Backdate the row past the freshness window without waiting for
        -- real time to pass — the same effect a push and 15 real minutes
        -- would have.
        assert(c.db:exec(
            "UPDATE ci_checks SET observed_at = observed_at - ? WHERE repo = ? AND pr = ?",
            {freshness.WINDOW_S + 1, REPO, 2}))
        local cached, age = ciobs.read(c, REPO, 2)
        assert(cached == "green", "the stale row still reads back its last state")
        assert(not ciobs.fresh(age), "and is no longer trusted: age " .. tostring(age))

        assert(render(s, c, 2) == "red", "the refresh picks up the new head's state")
        assert(calls == 2, "staleness earns exactly one more call: " .. tostring(calls))
        local cached2, age2 = ciobs.read(c, REPO, 2)
        assert(cached2 == "red", "and the row now holds the fresh state")
        assert(ciobs.fresh(age2))
        return true
      end)
    assert(cache.close(c))
  end

  -- `GITBOARD_CI_FRESH` forces past the window on every call, the CI
  -- counterpart of `_work.lanes.FRESH_ENV`: a hot loop that sets it pays
  -- for a live call every render, on purpose.
  local function test_fresh_env_forces_a_call_every_render()
    local s = init_state_repo("ciobs-forced")
    local c = assert(cache.open(s.root))
    local calls = 0
    assert(env.set(ciobs.FRESH_ENV, "0"))
    with_head_checks(function(_s: store.Store, _pr: integer, _repo: string | nil):
        gh.HeadChecks | nil, string
        calls = calls + 1
        return {state = "green", head_sha = "aaa", runs = {}}, ""
      end, function(): boolean
        assert(render(s, c, 3) == "green")
        assert(render(s, c, 3) == "green")
        assert(calls == 2, "the override is felt on every render: " .. tostring(calls))
        return true
      end)
    assert(env.unset(ciobs.FRESH_ENV))
    assert(cache.close(c))
  end

  --- A stored, PARENTED item carrying `pr`/`repo`, saved straight through
  --- `store.save` — `pr`/`repo` are refused on a root (`item.problems`),
  --- so each gets its own throwaway parent. `is_candidate` and `at_sync`
  --- care about the facts on the item, not how it got there, so a
  --- minimal decode is enough beyond that.
  --- @param s store.Store The store
  --- @param title string The item's title
  --- @param pr integer The PR number; 0 for none
  --- @return item.Item The saved item
  local function pr_item(s: store.Store, title: string, pr: integer): item.Item
    local parent = fixture.file_item(s, title .. " (parent)", "")
    local it = assert(item.decode({id = fixture.file_item(s, title, parent),
          title = title, parent = parent}))
    it.pr = pr
    it.repo = REPO
    assert(store.save(s, it, ("take %s by builder-a"):format(it.id:sub(1, 8))))
    return assert(store.load(s, it.id))
  end

  -- `is_candidate` is exactly "open, review stage, carries a PR" — a
  -- plain todo item and a resolved one are both excluded, only the
  -- review-stage item with a PR is a candidate.
  local function test_is_candidate_requires_open_review_stage_with_a_pr()
    local s = init_state_repo("ciobs-candidate")
    local todo = pr_item(s, "a todo item", 0)
    local reviewing = pr_item(s, "a reviewing item", 5)
    local done = pr_item(s, "a done item", 6)
    done.resolution = "completed"
    assert(store.save(s, done, "done " .. done.id:sub(1, 8) .. " completed (from todo)"))
    done = assert(store.load(s, done.id))

    assert(not ciobs.is_candidate(todo), "no PR is not a candidate")
    assert(ciobs.is_candidate(reviewing), "an open review-stage PR is a candidate")
    assert(not ciobs.is_candidate(done), "a resolved item is never a candidate")
  end

  -- `at_sync` observes a new candidate once, so the next `next` finds a
  -- fresh row waiting rather than paying for the call itself.
  local function test_at_sync_observes_a_new_candidate_once()
    local s = init_state_repo("ciobs-sync-new")
    local it = pr_item(s, "needs a first observation", 7)
    local calls = 0
    with_head_checks(function(_s: store.Store, _pr: integer, _repo: string | nil):
        gh.HeadChecks | nil, string
        calls = calls + 1
        return {state = "green", head_sha = "aaa", runs = {}}, ""
      end, function(): boolean
        local lines = ciobs.at_sync(s)
        assert(#lines == 0, "a clean observation prints nothing: "
          .. table.concat(lines, " | "))
        assert(calls == 1, tostring(calls))
        local c = assert(cache.open(s.root))
        local cached, age = ciobs.read(c, it.repo, it.pr)
        assert(cached == "green", tostring(cached))
        assert(ciobs.fresh(age))
        assert(cache.close(c))
        return true
      end)
  end

  -- A candidate already fresh is left alone: `at_sync` reuses the
  -- freshness window exactly as a render would, so running `sync` twice
  -- in a row costs nothing the second time.
  local function test_at_sync_skips_an_already_fresh_candidate()
    local s = init_state_repo("ciobs-sync-fresh")
    pr_item(s, "already observed", 8)
    local calls = 0
    with_head_checks(function(_s: store.Store, _pr: integer, _repo: string | nil):
        gh.HeadChecks | nil, string
        calls = calls + 1
        return {state = "green", head_sha = "aaa", runs = {}}, ""
      end, function(): boolean
        assert(#ciobs.at_sync(s) == 0)
        assert(calls == 1)
        assert(#ciobs.at_sync(s) == 0)
        assert(calls == 1, "the second sync reuses the fresh row: " .. tostring(calls))
        return true
      end)
  end

  -- An `observe` failure during `at_sync` is reported, not swallowed —
  -- the same discipline `_work.lanes.report` holds for a record or mint
  -- failure.
  local function test_at_sync_reports_an_observe_failure()
    local s = init_state_repo("ciobs-sync-fails")
    local it = pr_item(s, "cannot be observed", 9)
    with_head_checks(function(_s: store.Store, _pr: integer, _repo: string | nil):
        gh.HeadChecks | nil, string
        return nil, "network unreachable"
      end, function(): boolean
        local lines = ciobs.at_sync(s)
        assert(#lines == 1, table.concat(lines, " | "))
        assert(lines[1]:find(it.id:sub(1, 8), 1, true) ~= nil, lines[1])
        assert(lines[1]:find("network unreachable", 1, true) ~= nil, lines[1])
        return true
      end)
  end
