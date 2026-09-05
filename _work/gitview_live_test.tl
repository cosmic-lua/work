#!/usr/bin/env cosmic
-- `next`'s LIVE wiring — the real CI-state read and the stale-claim
-- snapshot a `gitboard next`/`show` invocation makes over a real store
-- — split out of `_work.gitview_test` (the pure, in-memory reports)
-- to keep that file under the repo's line cap.

local cache = require("_work.cache")
local check = require("cosmic.check")
local fixture = require("_work.fixture")
local gh = require("_work.gh")
local refs = require("_work.refs")
local store = require("_work.store")
local verbs = require("_work.gitverbs")
local view = require("_work.gitview")

--- Stand `gh.head_checks` in for a fixed state for the duration of
--- `f`, restoring the real function even when `f` fails an assertion
--- — the same swap-and-restore `gitreview_test.tl`'s `with_ci_state`
--- uses, sized to the two states this file actually exercises.
--- @param state string The state `head_checks` reports
--- @param f function(): boolean The test body; returns true when done
local function with_ci_state(state: string, f: function(): boolean)
  local real = gh.head_checks
  gh.head_checks = function(_s: store.Store, _pr: integer, _repo: string | nil):
    gh.HeadChecks | nil, string
    return {state = state, head_sha = "", runs = {}}, ""
  end
  local ok, err = pcall(f)
  gh.head_checks = real
  if not ok then
    error(err, 0)
  end
end

--- Run `view.cmd_next` and capture exactly what it prints via
--- `print()` -- the same swap-and-restore pattern `gitboard_test.tl`'s
--- `gitboard_and_capture` uses to pin a CLI's exact console output.
--- @param s store.Store The store
--- @param session string This session's name
--- @return integer cmd_next's exit code
--- @return string Every print()'d line, newline-joined
local function cmd_next_and_capture(s: store.Store, session: string):
  integer, string
  local old_print = _G.print
  local lines: {string} = {}
  _G.print = function(...: any)
    local parts: {string} = {}
    for i = 1, select("#", ...) do
      parts[i] = tostring((select(i, ...)))
    end
    lines[#lines + 1] = table.concat(parts, "\t")
  end
  local ok, result = pcall(view.cmd_next, s, session)
  _G.print = old_print
  if not ok then
    error(result, 0)
  end
  return result, table.concat(lines, "\n")
end

-- A reviewable item taken and handed over carrying a PR. The initial
-- claim is forced: the leaf's root is deliberately left unplaced (see
-- `unplaced_root_with_leaf`), and an unplaced item's own spec bar
-- normally refuses `take` — `--force` is only how this fixture skips
-- straight to "in review", not a claim about the real gate.
local function handed_over(s: store.Store, leaf: string, builder: string,
    pr: integer)
  fixture.give_spec(s, leaf)
  assert(verbs.cmd_take(s, leaf, builder, 0, true,
      "test fixture: skip the position gate") == 0)
  assert(verbs.cmd_take(s, leaf, builder, pr, false, "") == 0)
end

--- A deliberately UNPLACED root with one workable leaf under it — the
--- same shape `_work/action_ci_test.tl`'s
--- `test_a_running_head_is_not_offered` uses: it has a child (not
--- triage) and is not a placed root (nothing to decompose), so no
--- intake rung has anything to offer instead and the CI-blocked
--- review below is the only candidate `next` has to weigh.
--- @param s store.Store The store
--- @return string The workable leaf's id
local function unplaced_root_with_leaf(s: store.Store): string
  local root = fixture.file_item(s, "an outcome", "")
  return fixture.file_item(s, "a workable slice", root)
end

-- The wiring this item adds: `next` (through `gitview.cmd_next`, the
-- actual entry `gitboard next` reaches) reads live CI state for a
-- reviewable item carrying a PR and steps it out of the offer exactly
-- as `_work/action_ci_test.tl` proves `action.tl` alone can — proof
-- that a real `gitboard next` invocation now builds and passes the
-- `CiStates` map, not only that `next_action` honors one when handed
-- one directly.
local function test_live_next_skips_a_reviewable_item_with_ci_running()
  local s = fixture.init_state_repo("next-ci-running")
  local leaf = unplaced_root_with_leaf(s)
  handed_over(s, leaf, "builder-a", 9)
  with_ci_state("running", function(): boolean
      local code, printed = cmd_next_and_capture(s, "")
      assert(code == 0, printed)
      assert(printed:find("ci running", 1, true) ~= nil,
        "a running head is not offered by a live next: " .. printed)
      return true
    end)
end

-- Same wiring, the red case: already decided, but the move is the
-- builder's, not a reviewer's — and the live path renders that
-- distinctly from "running", the same as the pure layer already does.
local function test_live_next_skips_a_reviewable_item_with_ci_red()
  local s = fixture.init_state_repo("next-ci-red")
  local leaf = unplaced_root_with_leaf(s)
  handed_over(s, leaf, "builder-a", 9)
  with_ci_state("red", function(): boolean
      local code, printed = cmd_next_and_capture(s, "")
      assert(code == 0, printed)
      assert(printed:find("ci red — builder's", 1, true) ~= nil,
        "a red head reads as the builder's move on a live next: " .. printed)
      return true
    end)
end

--- Three separate roots, each with one workable leaf claimed under
--- its own builder — `claim_ages` only asks about a claimed item, so
--- three is enough to prove the cost stays flat rather than growing
--- with the count. `--force` skips the position gate the same way
--- `handed_over` does; none of these go to review, so `claim`, not
--- `reviewer`, is what makes each one eligible.
--- @param s store.Store The store
--- @return {string} The three claimed leaves' ids
local function three_claimed_leaves(s: store.Store): {string}
  local ids: {string} = {}
  for k = 1, 3 do
    local root = fixture.file_item(s, ("outcome %d"):format(k), "")
    local leaf = fixture.file_item(s, ("workable slice %d"):format(k), root)
    fixture.give_spec(s, leaf)
    assert(verbs.cmd_take(s, leaf, ("builder-%d"):format(k), 0, true,
        "test fixture: skip the position gate") == 0)
    ids[#ids + 1] = leaf
  end
  return ids
end

-- This item's own claim: `_work.read.stale` is a query over the
-- store's already-open cache — the SAME connection `list_via_cache`
-- opened — so `stale_ages` spawns no process of its own, no matter
-- how many items are claimed. None of these three is anywhere near
-- its lease (`_work.health.LEASE_S`, hours), so none appears in the
-- result: the cost property holds whether or not anything is stale.
local function test_stale_ages_costs_nothing_beyond_the_one_snapshot()
  local s = fixture.init_state_repo("claim-ages-snapshot")
  local ids = three_claimed_leaves(s)

  -- Warmed first, the way a real session's second-and-later render
  -- always finds the cache: `list_via_cache`'s own snapshot then
  -- reuses the file rather than paying `rebuild`'s cost too.
  local warm = check.must(cache.rebuild(s.root))
  assert(cache.close(warm))

  local board, lerr = view.list_via_cache(s)
  assert(board ~= nil, lerr)

  local calls = 0
  local real_fe = refs.for_each_ref
  refs.for_each_ref = function(root: string, patterns: {string}):
    {refs.RefEntry} | nil, string
    calls = calls + 1
    return real_fe(root, patterns)
  end
  local ages = view.stale_ages(s)
  refs.for_each_ref = real_fe

  assert(calls == 0, ("stale_ages should spawn nothing beyond the snapshot "
      .. "list_via_cache already took: got %d"):format(calls))
  for _, id in ipairs(ids) do
    assert(ages.claim[id] == nil,
      ("a freshly claimed item is nowhere near its lease: %s"):format(
        id:sub(1, 8)))
  end
end
