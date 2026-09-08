#!/usr/bin/env cosmic
-- `next`'s LIVE wiring — the real CI-state read and the stale-claim
-- snapshot a `gitboard next`/`show` invocation makes over a real store
-- — split out of `_work.gitview_test` (the pure, in-memory reports)
-- to keep that file under the repo's line cap.

local cache = require("_work.cache")
local check = require("cosmic.check")
local fixture = require("_work.fixture")
local fs = require("cosmic.fs")
local gitspec = require("_work.gitspec")
local item = require("_work.item")
local rank = require("_work.gitrank")
local refs = require("_work.refs")
local store = require("_work.store")
local storewrite = require("_work.storewrite")
local tail = require("_work.tail")
local verbs = require("_work.gitverbs")
local view = require("_work.gitview")

local tmpdir = os.getenv("TEST_TMPDIR") or "/tmp"
local BASE < const > = ("a"):rep(40)
local HEAD < const > = ("b"):rep(40)

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

-- A reviewable item with a commit-only handover. The initial
-- claim is forced: the leaf's root is deliberately left unplaced (see
-- `unplaced_root_with_leaf`), and an unplaced item's own spec bar
-- normally refuses `take` — `--force` is only how this fixture skips
-- straight to "in review", not a claim about the real gate.
local function handed_over(s: store.Store, leaf: string, builder: string)
  fixture.give_spec(s, leaf)
  local it = check.must(store.load(s, leaf))
  it.repo, it.claim, it.claim_base = "acme/widgets", builder, BASE
  it.handover_head = HEAD
  assert(item.record_involvement(it.builders, builder))
  assert(storewrite.save(s, it,
      ("take %s by %s head:%s"):format(leaf:sub(1, 8), builder,
        HEAD:sub(1, 12))))
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

-- `next` offers the exact handed-over commit without attempting to discover
-- provider check state. The caller inspects external checks on this SHA.
local function test_live_next_offers_a_commit_handover_without_provider_state()
  local s = fixture.init_state_repo("next-commit-review")
  local leaf = unplaced_root_with_leaf(s)
  handed_over(s, leaf, "builder-a")
  local code, printed = cmd_next_and_capture(s, "")
  assert(code == 0, printed)
  assert(printed:find(tail.handle(leaf), 1, true) ~= nil
    and printed:find("review", 1, true) ~= nil,
    "the commit handover is offered for review: " .. printed)
  assert(printed:find("ci running", 1, true) == nil
    and printed:find("ci red", 1, true) == nil,
    "next reconstructs no provider state: " .. printed)
end

-- A recommended head whose `Ready when:` mismatches is never offered:
-- a real `gitboard next` prints the not-ready line ahead of its next
-- candidate rather than recommending a pull `take` would only refuse.
local function test_live_next_skips_a_not_ready_head()
  local s = fixture.init_state_repo("next-ready-when")
  local root, first = fixture.root_with_leaf(s)
  local second = fixture.file_item(s, "a second workable slice", root)
  -- Both are otherwise unpositioned among the root's children, which
  -- ties them for the seeded tie-break — explicit order removes the
  -- tie, so `first` is deterministically the head this test is about.
  assert(rank.cmd_rank(s, first, "", "", true) == 0, "first ranks last")
  assert(rank.cmd_rank(s, second, "", first, false) == 0, "second after first")
  local path = fs.join(tmpdir, "ready-when-live.md")
  assert(fs.write(path, table.concat({
          "## Change", "Ready when: `printf ready` prints `done`.",
          "Do the thing.",
        }, "\n")))
  assert(gitspec.cmd_spec(s, first, path) == 0, "spec should be accepted")
  fixture.give_spec(s, second)

  local code, printed = cmd_next_and_capture(s, "")
  assert(code == 0, printed)
  assert(printed:find(
      "not ready: `printf ready` printed `ready`; ready means `done`",
      1, true) ~= nil,
    "the not-ready head's line prints ahead of the offer: " .. printed)
  assert(printed:find(tail.handle(second), 1, true) ~= nil,
    "the second candidate is recommended instead: " .. printed)
  assert(not printed:find("pull " .. tail.handle(first), 1, true),
    "the not-ready head is never itself recommended: " .. printed)
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
