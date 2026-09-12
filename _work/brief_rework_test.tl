#!/usr/bin/env cosmic
-- A builder brief's `<BOUNCE_CONTEXT>` fill for a rework hand-back —
-- an item that already carries a `request changes` verdict on an open
-- PR. Split from `_work/brief_test.tl`, which sits against the file
-- cap; every other brief kind and the fresh-pull path stay there. The
-- `<WORKTREE>` fill tests live here for the same reason: room.

local specmod = require("_work.spec")
local check = require("cosmic.check")
local child = require("cosmic.child")
local env = require("cosmic.env")
local fs = require("cosmic.fs")
local brief = require("_work.brief")
local claim = require("_work.claim")
local claimbatch = require("_work.claimbatch")
local fixture = require("_work.fixture")
local gitclaim = require("_work.gitclaim")
local item = require("_work.item")
local prepared = require("_work.prepared")
local store = require("_work.store")
local storewrite = require("_work.storewrite")

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

local BASE < const > = ("a"):rep(40)
local HEAD < const > = ("b"):rep(40)

--- One git command in `root`, failing loudly — fixture setup. Mirrors
--- `_work/brief_review_script_test.tl`'s own local `git` helper.
--- @param root string The checkout to run in
--- @param args {string} The git argv, without the leading "git"
--- @return string Trimmed stdout
local function git(root: string, args: {string}): string
  local argv: {string} = {"git", "-c", "user.email=test@example.com",
    "-c", "user.name=test"}
  for _, value in ipairs(args) do argv[#argv + 1] = value end
  local r = check.must(child.run(argv, {cwd = root}))
  assert(r.ok, r.stderr)
  return (r.stdout:gsub("%s+$", ""))
end

--- A real local product checkout mapped to "acme/widgets", with a real
--- claim batch prepared and promoted for `session-a` — the shape
--- `_work.brief`'s own `worktree_path` needs to derive `<WORKTREE>`: a
--- `gitboard.repository` mapping and a claim batch it can read state
--- from. Mirrors `_work/brief_review_script_test.tl`'s own
--- `handover_diff`.
--- @param s store.Store The store
--- @param leaf string The item id
--- @return string The product checkout's absolute path
local function claimed_item(s: store.Store, leaf: string): string
  local checkout = fs.join(os.getenv("TEST_TMPDIR") or "/tmp",
    "brief-rework-product-" .. leaf:sub(1, 8))
  assert(fs.remove_all(checkout) and fs.make_dirs(checkout))
  git(checkout, {"init", "-q"})
  assert(fs.write(fs.join(checkout, "README"), "base\n"))
  git(checkout, {"add", "README"})
  git(checkout, {"commit", "-q", "-m", "base"})
  local base = git(checkout, {"rev-parse", "HEAD"})
  fixture.git(s.root, {"config", "--local", "--add", "gitboard.repository",
      "acme/widgets=" .. checkout})
  local target = gitclaim.target_item_ref(leaf)
  local claimed = gitclaim.prepare_batch({{
        root = s.root, id = leaf, source_ref = target, target_ref = target,
        remote = "origin", batch = "brief-rework-" .. leaf:sub(1, 8),
        caller = "session-a", action = "take", product_base = base,
        force = false, why = "", now = os.time(),
      }})
  assert(claimed.prepared ~= nil,
    claimed.refused[leaf] or claimed.refused.batch)
  assert(prepared.promote_local(s.root, claimed.prepared.transaction))
  local it = assert(store.load(s, leaf))
  it.repo = "acme/widgets"
  assert(storewrite.save(s, it, "fixture: map repo for worktree derivation"))
  return checkout
end

-- `it.claim`/`it.claim_base` are projected from a claim-batch pointer at
-- read time (`_work.claimprojection`), never from the item's own history,
-- so the real claim comes from `claimed_item` rather than a direct field
-- assignment.
--- @return string The product checkout `claimed_item` made
local function handover_item(s: store.Store, leaf: string): string
  give_spec(s, leaf)
  local checkout = claimed_item(s, leaf)
  local it = assert(store.load(s, leaf))
  it.handover_head = HEAD
  assert(item.record_involvement(it.builders, "session-a"))
  assert(storewrite.save(s, it,
      ("take %s by session-a head:%s"):format(leaf:sub(1, 8), HEAD:sub(1, 12))))
  return checkout
end

-- A review needs distance from the builder: drop the standing build claim
-- (an active foreign claim refuses acquisition outright, even with
-- --force) and re-claim as the reviewer before a review brief will fill
-- one.
local function reclaim_for_review(s: store.Store, leaf: string)
  fixture.drop_claim(s, leaf, "session-a", "handed over")
  fixture.claim_item(s, leaf, "reviewer-a", BASE)
end

--- Put a fresh item in a v3 rework state without a provider object.
--- @param s store.Store The store
--- @param leaf string The item id
local function rework_item(s: store.Store, leaf: string)
  handover_item(s, leaf)
  local it = assert(store.load(s, leaf))
  it.claim, it.verdict_head, it.verdict = "reviewer-a", HEAD, "request changes"
  assert(storewrite.save(s, it,
      ("verdict %s request changes head:%s by reviewer-a")
      :format(leaf:sub(1, 8), HEAD:sub(1, 12))))
end

-- A rework hand-back fills `<BOUNCE_CONTEXT>` with the reviewer's
-- finding and the worktree-reuse/push instructions, so the
-- orchestrator no longer hand-assembles either one.
local function test_builder_rework_brief_uses_only_the_judged_commit()
  local s = init_state_repo("brief-rework")
  local _, leaf = root_with_leaf(s)
  rework_item(s, leaf)
  local code, out = brief_and_capture(s, "builder", leaf)
  assert(code == 0, "a commit rework item still earns its builder brief")
  assert(out:find("<BOUNCE_CONTEXT>", 1, true) == nil,
    "the placeholder is gone: " .. out)
  assert(out:find(HEAD, 1, true) ~= nil,
    "the exact judged commit identifies the rework: " .. out)
  assert(out:find("stores no review prose", 1, true) ~= nil,
    "the caller supplies findings out of band: " .. out)
  assert(out:find("GitHub", 1, true) == nil
    and out:find("pull request", 1, true) == nil,
    "the rework brief reconstructs no provider state: " .. out)
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
  local checkout = claimed_item(s, leaf)
  local it = assert(store.load(s, leaf))
  local st = assert(claimbatch.read_state(s.root, it.claim_batch or "", leaf))
  local wt = claim.worktree(checkout, claim.branch(leaf, st.root))
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

-- A review brief's `<WORKTREE>` fills once `worktree ID --review` has
-- actually made the checkout on disk — the same "unfilled until the
-- board can answer it" rule a builder's own case above follows.
local function test_review_brief_fills_worktree_once_it_exists()
  local s = init_state_repo("brief-wt-review")
  local _, leaf = root_with_leaf(s)
  local checkout = handover_item(s, leaf)
  reclaim_for_review(s, leaf)
  local it = assert(store.load(s, leaf))
  local st = assert(claimbatch.read_state(s.root, it.claim_batch or "", leaf))
  local expect = claim.worktree(checkout, claim.branch(leaf, st.root))
  assert(fs.make_dirs(expect))
  with_product_root(function(): boolean
      local code, out = brief_and_capture(s, "review", leaf)
      assert(code == 0, "a PR-bearing item still earns its review brief")
      assert(out:find(expect, 1, true) ~= nil,
        "the review brief names its own worktree path once it exists: " .. out)
      assert(out:find("<WORKTREE>", 1, true) == nil,
        "the placeholder is gone: " .. out)
      return true
    end)
end

-- Before `worktree ID --review` runs, the path does not exist yet, so
-- the placeholder survives — the same pair a builder's own case above
-- makes.
local function test_review_brief_leaves_worktree_unfilled_before_worktree_id_runs()
  local s = init_state_repo("brief-wt-review-missing")
  local _, leaf = root_with_leaf(s)
  handover_item(s, leaf)
  reclaim_for_review(s, leaf)
  with_product_root(function(): boolean
      local code, out = brief_and_capture(s, "review", leaf)
      assert(code == 0)
      assert(out:find("<WORKTREE>", 1, true) ~= nil,
        "no worktree on disk yet, so the placeholder survives: " .. out)
      local verdict_line = out:match("[^\n]*$")
      assert(verdict_line:find("WORKTREE", 1, true) ~= nil,
        "the verdict line names it as still owed: " .. verdict_line)
      return true
    end)
end

-- Rework prose belongs in the caller's handoff, not in the board. A fresh
-- commit review therefore contains no provider-derived round context.
local function test_review_brief_has_no_provider_round_context()
  local s = init_state_repo("brief-round-context-first")
  local _, leaf = root_with_leaf(s)
  handover_item(s, leaf)
  reclaim_for_review(s, leaf)
  local code, out = brief_and_capture(s, "review", leaf)
  assert(code == 0, "a commit handover still earns its review brief")
  assert(out:find("<ROUND_CONTEXT>", 1, true) == nil
    and out:find("CHANGES_REQUESTED", 1, true) == nil,
    "no provider review history is reconstructed: " .. out)
end

-- The closing "nothing left to fill" line is only true once `<WORKTREE>`
-- has an answer too — the trap this rewrite must not fall back into:
-- with no worktree on disk, `<WORKTREE>` would survive and flip this
-- test's own final-line assertion.
local function test_review_brief_preserves_literal_template_tokens_in_spec()
  local s = init_state_repo("brief-literal-spec")
  local _, leaf = root_with_leaf(s)
  local checkout = handover_item(s, leaf)
  reclaim_for_review(s, leaf)
  local it = assert(store.load(s, leaf))
  local st = assert(claimbatch.read_state(s.root, it.claim_batch or "", leaf))
  assert(fs.make_dirs(claim.worktree(checkout, claim.branch(leaf, st.root))))
  local prose = check.must(specmod.split(
      "## Change\nKeep <CONST_NAME>, {{.field}}, and <HEAD_SHA> verbatim.\n"
      .. "## Non-goals\nNothing else.\n"))
  local spec = specmod.document(prose)
  assert(storewrite.save(s, it, "spec literal template tokens", prose))
  with_product_root(function(): boolean
      local code, out = brief_and_capture(s, "review", leaf)
      assert(code == 0, "a commit handover still earns its review brief")
      assert(out:find(spec, 1, true) ~= nil,
        "the complete spec remains verbatim in the rendered brief: " .. out)
      local final_line = out:match("[^\n]*$")
      assert(final_line:find("nothing left to fill", 1, true) ~= nil,
        "the final line confirms every genuine placeholder was filled: " .. final_line)
      return true
    end)
end
