#!/usr/bin/env cosmic
-- A builder brief's `<BOUNCE_CONTEXT>` fill for a rework hand-back —
-- an item that already carries a `request changes` verdict on an open
-- PR. Split from `_work/brief_test.tl`, which sits against the file
-- cap; every other brief kind and the fresh-pull path stay there.

local brief = require("_work.brief")
local fixture = require("_work.fixture")
local gh = require("_work.gh")
local store = require("_work.store")
local verbs = require("_work.gitverbs")
local vrd = require("_work.gitverdict")

local init_state_repo = fixture.init_state_repo
local give_spec = fixture.give_spec
local root_with_leaf = fixture.root_with_leaf

--- Run brief.cmd_brief and capture exactly what it prints via
--- print() — the same swap-and-restore pattern `_work.brief_test`'s
--- own `brief_and_capture` uses.
--- @param s store.Store The store
--- @param kind string The brief kind
--- @param id string The item id
--- @return integer cmd_brief's exit code
--- @return string Every print()'d line, newline-joined
local function brief_and_capture(s: store.Store, kind: string,
    id: string): integer, string
  local old_print = _G.print
  local lines: {string} = {}
  _G.print = function(...: any)
    local parts: {string} = {}
    for i = 1, select("#", ...) do
      parts[i] = tostring((select(i, ...)))
    end
    lines[#lines + 1] = table.concat(parts, "\t")
  end
  local ok, result = pcall(brief.cmd_brief, s, kind, id)
  _G.print = old_print
  if not ok then
    error(result, 0)
  end
  return result, table.concat(lines, "\n")
end

--- Stand `gh.reviews` in for a fixed review list for the duration of
--- `f`, restoring it even when `f` fails an assertion — the same
--- swap-and-restore pattern `_work.brief_test`'s `with_ci_fixture`
--- uses for the PR reads. `revs` nil fakes a read failure (no token,
--- no network, whatever the reason), the same shape a real
--- `gh.reviews` reports one with.
--- @param revs {gh.Review} | nil The reviews to hand back, nil for a read failure
--- @param f function(): boolean The test body; returns true when done
local function with_reviews_fixture(revs: {gh.Review} | nil, f: function(): boolean)
  local real_reviews = gh.reviews
  gh.reviews = function(_s: store.Store, _number: integer, _repo: string | nil):
    {gh.Review} | nil, string
    if revs == nil then
      return nil, "stub review read failure"
    end
    return revs, ""
  end
  local ok, err = pcall(f)
  gh.reviews = real_reviews
  if not ok then
    error(err, 0)
  end
end

--- Take a fresh item all the way to a rework hand-back: claimed,
--- handed over on `pr`, and sent back with a `request changes`
--- verdict — the standing state `brief`'s `<BOUNCE_CONTEXT>` fill
--- looks for.
--- @param s store.Store The store
--- @param leaf string The item id
--- @param pr integer The PR the verdict judges
local function rework_item(s: store.Store, leaf: string, pr: integer)
  give_spec(s, leaf)
  assert(verbs.cmd_take(s, leaf, "session-a", 0, false, "") == 0)
  assert(verbs.cmd_take(s, leaf, "session-a", pr, false, "") == 0)
  assert(vrd.cmd_verdict(s, leaf, "request changes", pr, "abc1234",
      "reviewer-a") == 0)
end

-- A rework hand-back fills `<BOUNCE_CONTEXT>` with the reviewer's
-- finding and the worktree-reuse/push instructions, so the
-- orchestrator no longer hand-assembles either one.
local function test_builder_rework_brief_fills_bounce_context()
  local s = init_state_repo("brief-rework")
  local _, leaf = root_with_leaf(s)
  rework_item(s, leaf, 42)
  with_reviews_fixture({
      {state = "CHANGES_REQUESTED", body = "fix the flaky retry",
        submitted_at = "2024-01-01T00:00:00Z"},
    }, function(): boolean
      local code, out = brief_and_capture(s, "builder", leaf)
      assert(code == 0, "a rework item still earns its builder brief")
      assert(out:find("<BOUNCE_CONTEXT>", 1, true) == nil,
        "the placeholder is gone: " .. out)
      assert(out:find("fix the flaky retry", 1, true) ~= nil,
        "the reviewer's finding rides verbatim: " .. out)
      assert(out:find("rework, not a fresh pull", 1, true) ~= nil,
        "the rework section names itself: " .. out)
      assert(out:find("do NOT branch fresh", 1, true) ~= nil,
        "worktree reuse is spelled out: " .. out)
      assert(out:find("git push origin " .. leaf:sub(1, 8), 1, true) ~= nil,
        "push a fix to the item's own branch, not a new PR: " .. out)
      return true
    end)
end

-- GitHub lists every review a PR has ever carried, in no order a
-- caller should rely on; the fill picks the MOST RECENT
-- CHANGES_REQUESTED one by `submitted_at`, skipping an approval and an
-- older, already-superseded round.
local function test_builder_rework_brief_picks_the_latest_review()
  local s = init_state_repo("brief-rework-multi")
  local _, leaf = root_with_leaf(s)
  rework_item(s, leaf, 42)
  with_reviews_fixture({
      {state = "CHANGES_REQUESTED", body = "an older, already-fixed complaint",
        submitted_at = "2024-01-01T00:00:00Z"},
      {state = "APPROVED", body = "looks fine now",
        submitted_at = "2024-01-03T00:00:00Z"},
      {state = "CHANGES_REQUESTED", body = "the real, current finding",
        submitted_at = "2024-01-02T00:00:00Z"},
    }, function(): boolean
      local _code, out = brief_and_capture(s, "builder", leaf)
      assert(out:find("the real, current finding", 1, true) ~= nil,
        "the most recent CHANGES_REQUESTED review wins: " .. out)
      assert(out:find("an older, already-fixed complaint", 1, true) == nil,
        "an earlier round's finding does not ride along: " .. out)
      return true
    end)
end

-- A read failure (no token, no network, no reviews at all) leaves
-- `<BOUNCE_CONTEXT>` exactly as unfilled as a fresh pull's — never a
-- new failure mode, and never a brief the caller cannot still emit.
local function test_builder_rework_brief_survives_a_review_read_failure()
  local s = init_state_repo("brief-rework-noread")
  local _, leaf = root_with_leaf(s)
  rework_item(s, leaf, 42)
  with_reviews_fixture(nil, function(): boolean
      local code, out = brief_and_capture(s, "builder", leaf)
      assert(code == 0, "a read failure never blocks the brief")
      assert(out:find("<BOUNCE_CONTEXT>", 1, true) ~= nil,
        "the placeholder survives exactly as a fresh pull's does: " .. out)
      return true
    end)
end

-- A rework item whose PR carries no CHANGES_REQUESTED review at all
-- (only an approval, say) leaves the placeholder unfilled the same way.
local function test_builder_rework_brief_with_no_matching_review()
  local s = init_state_repo("brief-rework-none")
  local _, leaf = root_with_leaf(s)
  rework_item(s, leaf, 42)
  with_reviews_fixture({
      {state = "APPROVED", body = "lgtm", submitted_at = "2024-01-01T00:00:00Z"},
    }, function(): boolean
      local code, out = brief_and_capture(s, "builder", leaf)
      assert(code == 0)
      assert(out:find("<BOUNCE_CONTEXT>", 1, true) ~= nil,
        "no CHANGES_REQUESTED review, so nothing to fill it with: " .. out)
      return true
    end)
end
