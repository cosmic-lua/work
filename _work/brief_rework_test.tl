#!/usr/bin/env cosmic
-- A builder brief's `<BOUNCE_CONTEXT>` fill for a rework hand-back —
-- an item that already carries a `request changes` verdict on an open
-- PR. Split from `_work/brief_test.tl`, which sits against the file
-- cap; every other brief kind and the fresh-pull path stay there. The
-- `<WORKTREE>` fill tests live here for the same reason: room.

local env = require("cosmic.env")
local fs = require("cosmic.fs")
local brief = require("_work.brief")
local fixture = require("_work.fixture")
local gh = require("_work.gh")
local review = require("_work.review")
local store = require("_work.store")
local verbs = require("_work.gitverbs")
local vrd = require("_work.gitverdict")

-- A real `<root>/bin/gitboard` product_root()'s dirname-dirname guess
-- can verify — a second one, distinct from `_work.brief_test`'s own,
-- so the two files never race on the same path.
local WT_ROOT < const > = fs.join(os.getenv("TEST_TMPDIR") or "/tmp", "brief-wt-product-root")
assert(fs.make_dirs(fs.join(WT_ROOT, "bin"))
  and fs.write(fs.join(WT_ROOT, "bin/gitboard"), ""))

--- Point `GITBOARD_DIR` at `WT_ROOT/o/board` (so `product_root()`
--- resolves to `WT_ROOT`) for the duration of `f`, restoring whatever
--- it was before — the same borrow-and-restore `_work.brief_test`'s
--- own PRODUCT_ROOT tests use.
--- @param f function(): boolean The test body; returns true when done
local function with_product_root(f: function(): boolean)
  local prior = env.get("GITBOARD_DIR")
  assert(env.set("GITBOARD_DIR", fs.join(WT_ROOT, "o/board")))
  local ok, err = pcall(f)
  if prior == nil then local _ok, _err = env.unset("GITBOARD_DIR")
  else assert(env.set("GITBOARD_DIR", prior)) end
  if not ok then
    error(err, 0)
  end
end

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

--- Stand `gh.head_checks`, `gh.pull` and `gh.get_files` in for a green,
--- non-mechanical PR at a fixed head — the same fixture shape
--- `_work.brief_test`'s own `with_ci_fixture` uses for its "green"
--- case, reused here so a review brief's `<ROUND_CONTEXT>` fill can be
--- exercised without dragging that file's whole state table along.
--- @param sha string The PR's current head
--- @param f function(): boolean The test body; returns true when done
local function with_review_pr_fixture(sha: string, f: function(): boolean)
  local real_head_checks, real_pull, real_get_files
  = gh.head_checks, gh.pull, gh.get_files
  gh.head_checks = function(_s: store.Store, _pr: integer, _repo: string | nil):
    gh.HeadChecks | nil, string
    return {state = "green", head_sha = sha, runs = {}}, ""
  end
  gh.pull = function(_s: store.Store, number: integer, _repo: string | nil):
    review.Pull | nil, string
    return {number = number, draft = false, merged = false, body = "",
      head_sha = sha, base = "", state = "open", merge_sha = "",
      additions = 120, deletions = 30}, ""
  end
  gh.get_files = function(_s: store.Store, _n: integer, _r: string | nil):
    {string} | nil, string
    return {"cosmic/example.tl"}, ""
  end
  local ok, err = pcall(f)
  gh.head_checks, gh.pull, gh.get_files = real_head_checks, real_pull, real_get_files
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

-- A reviewer's finding is ordinary review prose, not a placeholder
-- source: `<CONST_NAME>`-shaped text inside it (this codebase's own
-- naming convention, so entirely routine to write in a review) must
-- never be reported as something the caller still owes a fill for.
local function test_builder_rework_brief_does_not_mistake_review_prose_for_a_placeholder()
  local s = init_state_repo("brief-rework-injection")
  local _, leaf = root_with_leaf(s)
  rework_item(s, leaf, 42)
  with_reviews_fixture({
      {state = "CHANGES_REQUESTED",
        body = "please rename to <CONST_NAME> and check <ENV_VAR>",
        submitted_at = "2024-01-01T00:00:00Z"},
    }, function(): boolean
      local code, out = brief_and_capture(s, "builder", leaf)
      assert(code == 0)
      assert(out:find("please rename to <CONST_NAME> and check <ENV_VAR>",
          1, true) ~= nil,
        "the finding still rides verbatim in the printed body: " .. out)
      local verdict_line = out:match("[^\n]*$")
      assert(verdict_line:find("<CONST_NAME>", 1, true) == nil,
        "review prose shaped like a placeholder is not reported as "
        .. "unfilled: " .. verdict_line)
      assert(verdict_line:find("<ENV_VAR>", 1, true) == nil,
        "same for the second one: " .. verdict_line)
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

-- On the token's OWN pull request GitHub refuses REQUEST_CHANGES, so
-- `_work.ghwrite.post_review` posts a COMMENT marked with a
-- `request-changes:` first line instead — the bounce still fills,
-- `gh.latest_request_changes` reading the marked COMMENT the same way
-- it would a formal CHANGES_REQUESTED review.
local function test_builder_rework_brief_fills_from_an_own_pr_comment()
  local s = init_state_repo("brief-rework-own-pr")
  local _, leaf = root_with_leaf(s)
  rework_item(s, leaf, 42)
  with_reviews_fixture({
      {state = "COMMENTED",
        body = "request-changes:\nthe retry never backs off",
        submitted_at = "2024-01-01T00:00:00Z"},
    }, function(): boolean
      local code, out = brief_and_capture(s, "builder", leaf)
      assert(code == 0, "an own-PR bounce still earns its builder brief")
      assert(out:find("<BOUNCE_CONTEXT>", 1, true) == nil,
        "the placeholder is gone: " .. out)
      assert(out:find("the retry never backs off", 1, true) ~= nil,
        "the marked COMMENT's finding rides, marker included, verbatim: "
        .. out)
      return true
    end)
end

-- Unrelated to rework — kept here rather than in `_work/brief_test.tl`
-- for the same reason this file split off it: room under the file
-- cap. The sibling-reuse bootstrap sets GITBOARD_DIR to a sibling
-- clone's own root, never `<root>/o/board`, so the dirname-dirname
-- guess lands on a directory with no `bin/gitboard` at all;
-- PRODUCT_ROOT must then fall back to searching upward from this
-- process's own working directory — always inside the real product
-- checkout that invoked `bin/gitboard` — for the nearest ancestor
-- that has one.
local function test_product_root_falls_back_to_cwd_when_the_guess_is_wrong()
  local s = init_state_repo("brief-product-root-cwd")
  local _, leaf = root_with_leaf(s)
  give_spec(s, leaf)
  local tmpdir = os.getenv("TEST_TMPDIR") or "/tmp"
  local root = fs.join(tmpdir, "brief-product-root-cwd")
  assert(fs.remove_all(root))
  assert(fs.make_dirs(fs.join(root, "bin")))
  assert(fs.write(fs.join(root, "bin/gitboard"), ""))
  local nested = fs.join(root, "nested/deep")
  assert(fs.make_dirs(nested))
  local prior_cwd, cerr = fs.cwd()
  assert(prior_cwd, cerr)
  local prior_dir = env.get("GITBOARD_DIR")
  -- Sibling-shaped: the sibling clone's OWN root, not <root>/o/board —
  -- its dirname-dirname has no bin/gitboard, so the guess must fail.
  assert(env.set("GITBOARD_DIR", fs.join(tmpdir, "brief-product-root-cwd-sibling")))
  assert(fs.set_cwd(nested))
  local code, out = brief_and_capture(s, "refine", leaf)
  assert(fs.set_cwd(prior_cwd))
  if prior_dir == nil then local _ok, _err = env.unset("GITBOARD_DIR")
  else assert(env.set("GITBOARD_DIR", prior_dir)) end
  assert(code == 0, "a spec-bearing item still earns its refine brief")
  assert(out:find("cd " .. root .. "\n", 1, true) ~= nil,
    "PRODUCT_ROOT falls back to the cwd ancestor holding bin/gitboard, "
    .. "not the wrong dirname-dirname guess: " .. out)
end

-- A builder brief's `<WORKTREE>` fills only once `worktree ID` has
-- actually made the checkout on disk — the same "unfilled until the
-- board can answer it" rule every other placeholder follows, so a
-- claim with no worktree yet still emits a usable (if incomplete)
-- brief rather than a wrong path.
local function test_builder_brief_fills_worktree_once_it_exists()
  local s = init_state_repo("brief-wt-builder")
  local _, leaf = root_with_leaf(s)
  give_spec(s, leaf)
  local id8 = leaf:sub(1, 8)
  local wt = fs.join(fs.dirname(WT_ROOT), "wt", id8)
  assert(fs.make_dirs(wt))
  with_product_root(function(): boolean
      local code, out = brief_and_capture(s, "builder", leaf)
      assert(code == 0, "a spec-bearing item still earns its builder brief")
      assert(out:find(wt, 1, true) ~= nil,
        "WORKTREE fills once worktree ID made the checkout: " .. out)
      assert(out:find("<WORKTREE>", 1, true) == nil,
        "the placeholder is gone: " .. out)
      return true
    end)
end

-- Before `worktree ID` runs, the path does not exist yet, so the
-- placeholder survives — the verdict line's job is to say so, never
-- to guess a path nobody made.
local function test_builder_brief_leaves_worktree_unfilled_before_worktree_id_runs()
  local s = init_state_repo("brief-wt-builder-missing")
  local _, leaf = root_with_leaf(s)
  give_spec(s, leaf)
  with_product_root(function(): boolean
      local code, out = brief_and_capture(s, "builder", leaf)
      assert(code == 0)
      assert(out:find("<WORKTREE>", 1, true) ~= nil,
        "no worktree on disk yet, so the placeholder survives: " .. out)
      local verdict_line = out:match("[^\n]*$")
      assert(verdict_line:find("WORKTREE", 1, true) ~= nil,
        "the verdict line names it as still owed: " .. verdict_line)
      return true
    end)
end

-- A review brief names its OWN worktree path unconditionally: the
-- reviewer creates it fresh, so there is nothing on disk to check
-- for, unlike a builder's already-made checkout.
local function test_review_brief_names_its_own_worktree_path_unconditionally()
  local s = init_state_repo("brief-wt-review")
  local _, leaf = root_with_leaf(s)
  give_spec(s, leaf)
  assert(verbs.cmd_take(s, leaf, "session-a", 0, false, "") == 0)
  assert(verbs.cmd_take(s, leaf, "session-a", 9, false, "") == 0)
  local id8 = leaf:sub(1, 8)
  local expect = fs.join(fs.dirname(WT_ROOT), "wt", "review-" .. id8)
  with_product_root(function(): boolean
      local code, out = brief_and_capture(s, "review", leaf)
      assert(code == 0, "a PR-bearing item still earns its review brief")
      assert(out:find(expect, 1, true) ~= nil,
        "the review brief names its own fresh-checkout path: " .. out)
      assert(out:find("<WORKTREE>", 1, true) == nil,
        "the placeholder is gone: " .. out)
      return true
    end)
end

-- A second review round fills `<ROUND_CONTEXT>` with round 1's own
-- formal review, verbatim, plus the fixed "what round 1 accepted is
-- settled" sentence — so a reviewer never relitigates ground round 1
-- already covered. Filled only once the PR's head has actually moved
-- past the one the standing verdict judged; `rework_item` records that
-- judged head as `abc1234`, so a current head of anything else is a
-- move.
local function test_review_brief_fills_round_context_after_a_moved_head()
  local s = init_state_repo("brief-round-context")
  local _, leaf = root_with_leaf(s)
  rework_item(s, leaf, 42)
  with_reviews_fixture({
      {state = "CHANGES_REQUESTED", body = "the fs.join call leaks a temp dir",
        submitted_at = "2024-01-01T00:00:00Z"},
    }, function(): boolean
      with_review_pr_fixture("deadbee0feedfacebeef1234567890abcdef1234",
        function(): boolean
          local code, out = brief_and_capture(s, "review", leaf)
          assert(code == 0, "a moved-head rework item still earns its review brief")
          assert(out:find("the fs.join call leaks a temp dir", 1, true) ~= nil,
            "round 1's review body rides verbatim: " .. out)
          assert(out:find("Confirm each finding above is closed — repeat "
              .. "its own reproduction —", 1, true) ~= nil
            and out:find("what round 1 accepted is settled.", 1, true) ~= nil,
            "the fixed sentence rides verbatim: " .. out)
          assert(out:find("<ROUND_CONTEXT>", 1, true) == nil,
            "the placeholder is gone: " .. out)
          return true
        end)
      return true
    end)
end

-- A first-round item — no standing `request changes` verdict at all —
-- fills `<ROUND_CONTEXT>` as empty: neither round 1's review nor the
-- fixed sentence has anything to say about a review that has not
-- happened yet.
local function test_review_brief_leaves_round_context_empty_on_a_first_round()
  local s = init_state_repo("brief-round-context-first")
  local _, leaf = root_with_leaf(s)
  give_spec(s, leaf)
  assert(verbs.cmd_take(s, leaf, "session-a", 0, false, "") == 0)
  assert(verbs.cmd_take(s, leaf, "session-a", 9, false, "") == 0)
  with_review_pr_fixture("cafef00dfeedfacebeef1234567890abcdef1234",
    function(): boolean
      local code, out = brief_and_capture(s, "review", leaf)
      assert(code == 0, "a first-round item still earns its review brief")
      assert(out:find("accepted is settled", 1, true) == nil,
        "no round context on a first round: " .. out)
      assert(out:find("<ROUND_CONTEXT>", 1, true) == nil,
        "empty, not the raw placeholder: " .. out)
      return true
    end)
end
