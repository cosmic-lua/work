#!/usr/bin/env cosmic
-- The brief verb: board facts fill, the spec rides verbatim, what the
-- board cannot answer survives as a placeholder the verdict line
-- names, and the refusals hold — an unknown kind, a spec-less item
-- for the kinds that carry the spec, a review with no PR recorded.

local check = require("cosmic.check")
local child = require("cosmic.child")
local env = require("cosmic.env")
local fs = require("cosmic.fs")
local brief = require("_work.brief")
local brieftext_friction = require("_work.brieftext_friction")
local claim = require("_work.claim")
local claimbatch = require("_work.claimbatch")
local fixture = require("_work.fixture")
local gitinvocation = require("_work.gitinvocation")
local gitspec = require("_work.gitspec")
local item = require("_work.item")
local specmod = require("_work.spec")
local store = require("_work.store")
local storewrite = require("_work.storewrite")
local tail = require("_work.tail")

local init_state_repo = fixture.init_state_repo
local give_spec = fixture.give_spec
local root_with_leaf = fixture.root_with_leaf

-- A real `<root>/bin/gitboard` product_root()'s dirname-dirname guess can verify.
local PRODUCT_ROOT < const > = fs.join(os.getenv("TEST_TMPDIR") or "/tmp", "brief-product-root")
assert(fs.make_dirs(fs.join(PRODUCT_ROOT, "bin")) and fs.write(fs.join(PRODUCT_ROOT, "bin/gitboard"), ""))

local BASE < const > = ("a"):rep(40)
local HEAD < const > = ("b"):rep(40)

--- Put an item in the v3 commit-handover shape without involving a provider.
--- `it.claim`/`it.claim_base` are projected from a claim-batch pointer at
--- read time (`_work.claimprojection`), never from the item's own history,
--- so the real claim comes from `fixture.claim_item` rather than a direct
--- field assignment — a workflow transition never releases the claim, so
--- this leaves "session-a" holding it exactly as a real handover would.
local function handover(s: store.Store, id: string, url?: string)
  fixture.claim_item(s, id, "session-a", BASE)
  local it = check.must(store.load(s, id))
  it.repo = "acme/widgets"
  it.handover_head = HEAD
  it.external_url = url or ""
  assert(item.record_involvement(it.builders, "session-a"))
  assert(storewrite.save(s, it,
      ("take %s by session-a head:%s"):format(id:sub(1, 8), HEAD:sub(1, 12))))
end

local function research_handover(s: store.Store, id: string)
  local it = check.must(store.load(s, id))
  it.claim = "session-a"
  assert(item.record_involvement(it.builders, "session-a"))
  it.result = specmod.revision(store.read_spec(s, id))
  assert(storewrite.save(s, it,
      ("take %s by session-a result:%s"):format(
        id:sub(1, 8), it.result:sub(1, 7))))
end

--- Move `id`'s claim from the builder to a fresh reviewing session, the
--- step the orchestrator takes between a builder's handover and `brief
--- review ID` — dropping the standing builder claim first, since an
--- active foreign claim refuses acquisition outright, even with
--- `--force` (`_work.gitclaim_test`'s
--- `test_active_foreign_claim_refuses_even_when_force_is_requested`).
--- Without this, the claim stays the builder's own and a review brief
--- refuses (`distance_refusal`) — the point of the fix this file's own
--- `brief_session_test.tl` sibling covers; this helper just keeps the
--- tests below that exercise unrelated review behavior past it.
--- @param s store.Store The store
--- @param id string The item id
--- @param session string The reviewing session to claim under
local function reclaim(s: store.Store, id: string, session: string)
  fixture.drop_claim(s, id, "session-a", "handed over")
  fixture.claim_item(s, id, session, BASE)
end

--- Run brief.cmd_brief and capture exactly what it prints via
--- print() — the swap-and-restore pattern the other verb tests use.
--- @param s store.Store The store
--- @param kind string The brief kind
--- @param id string The item id
--- @return integer cmd_brief's exit code
--- @return string Every print()'d line, newline-joined
local function brief_and_capture(s: store.Store, kind: string,
    id: string, tree?: string): integer, string
  local old_print = _G.print
  local lines: {string} = {}
  _G.print = function(...: any)
    local parts: {string} = {}
    for i = 1, select("#", ...) do
      parts[i] = tostring((select(i, ...)))
    end
    lines[#lines + 1] = table.concat(parts, "\t")
  end
  local ok, result = pcall(brief.cmd_brief, s, kind, id, nil, tree)
  _G.print = old_print
  if not ok then
    error(result, 0)
  end
  return result, table.concat(lines, "\n")
end

local function stale_board_sentence(s: store.Store): string
  return "The checkout that holds the board worktree (`"
  .. fs.absolute_path(s.root)
  .. "/..`) is the orchestrator's and is stale by construction; never read, grep or build in it. Your worktree is the only tree."
end

local function flat_text(text: string): string
  return (text:gsub("%s+", " "))
end

--- The claim's own `work/<handle>/<claim>` branch — the same string
--- `_work.brief`'s `claim_branch` derives — read back independently so
--- the assertion does not just echo the code under test.
--- @param s store.Store The board
--- @param id string The claimed item's id
--- @return string The branch `worktree ID` would create
local function branch_of(s: store.Store, id: string): string
  local it = check.must(store.load(s, id))
  local st = check.must(claimbatch.read_state(s.root, it.claim_batch or "", id))
  return claim.branch(id, st.root)
end

local function test_tree_measurement_appends_to_builder_and_review()
  local s = init_state_repo("brief-tree")
  local _, leaf = root_with_leaf(s)
  local path = fs.join(s.root, "-probe.tl")
  assert(fs.write(path, ("line\n"):rep(490)))
  local spec_file = fs.join(s.root, "tree-spec.md")
  assert(fs.write(spec_file, [[
## Change
-probe.tl and absent.tl
## Non-goals
No refusal.
]]))
  assert(gitspec.cmd_spec(s, leaf, spec_file) == 0)
  local add = check.must(child.run({"git", "add", "--", "-probe.tl"}, {cwd = s.root}))
  assert(add.ok, "the measurement fixture is staged: " .. add.stderr)
  local commit = check.must(child.run({"git", "-c", "user.email=test@example.com",
        "-c", "user.name=test", "commit", "-q", "-m", "measurement fixture"},
      {cwd = s.root}))
  assert(commit.ok, "the measurement fixture has a HEAD: " .. commit.stderr)
  local code, out = brief_and_capture(s, "builder", leaf, s.root)
  assert(code == 0, "tree measurement earns a builder brief: " .. out)
  assert(out:find("## Measured at brief time (" .. s.root .. ", ", 1, true) ~= nil,
    "the measured section names the tree and HEAD: " .. out)
  assert(out:find("-probe.tl  490 lines (10 under the 500 cap)", 1, true) ~= nil,
    "the measured file carries its headroom: " .. out)
  assert(out:find("absent.tl  absent", 1, true) ~= nil,
    "the missing Change path is explicit: " .. out)
  assert(out:find("measured Change paths under " .. s.root, 1, true) ~= nil,
    "the verdict names what was measured: " .. out)
  handover(s, leaf)
  reclaim(s, leaf, "session-b")
  local review_code, review_out = brief_and_capture(s, "review", leaf, s.root)
  assert(review_code == 0, "tree measurement earns a review brief: " .. review_out)
  assert(review_out:find("-probe.tl  490 lines (10 under the 500 cap)", 1, true) ~= nil,
    "review carries the measured section: " .. review_out)
end

local function test_tree_measurement_refuses_a_non_directory()
  local s = init_state_repo("brief-tree-refusal")
  local _, leaf = root_with_leaf(s)
  give_spec(s, leaf)
  local not_dir = fs.join(s.root, "not-a-directory.tl")
  assert(fs.write(not_dir, "not a directory\n"))
  local code, out = brief_and_capture(s, "builder", leaf, not_dir)
  assert(code ~= 0, "a non-directory --tree is refused")
  assert(out:find("--tree '" .. not_dir .. "' must be a directory", 1, true) ~= nil,
    "the refusal is a verdict line: " .. out)
end

local function test_fill_answers_only_what_the_map_holds()
  local out = brief.fill("a <ONE> b <TWO> c <lower>", {ONE = "1"})
  assert(out == "a 1 b <TWO> c <lower>", out)
  local left = brief.unfilled(out)
  assert(#left == 1 and left[1] == "<TWO>",
    "lowercase brackets are prose, not placeholders")
end

local function test_builder_brief_carries_the_item_and_names_the_rest()
  local s = init_state_repo("brief-builder")
  local _, leaf = root_with_leaf(s)
  give_spec(s, leaf)
  local code, out = brief_and_capture(s, "builder", leaf)
  assert(code == 0, "a specced item earns its builder brief")
  assert(out:find(leaf, 1, true) ~= nil, "the full id rides the brief")
  assert(flat_text(out):find(flat_text(stale_board_sentence(s)), 1, true) ~= nil,
    "the builder names the stale board checkout and fills its path")
  assert(out:find("<BOARD_DIR>", 1, true) == nil,
    "the builder fills the board directory placeholder")
  assert(out:find(tail.handle(leaf), 1, true) ~= nil, "so does the handle")
  assert(out:find("Do exactly this.", 1, true) ~= nil,
    "the spec sidecar rides verbatim")
  assert(out:find("<WORKTREE>", 1, true) ~= nil
    and out:find("<BOUNCE_CONTEXT>", 1, true) ~= nil
    and out:find("<BRANCH>", 1, true) ~= nil,
    "an unclaimed item has no branch to derive either, so it too "
    .. "survives the fill rather than naming a guessed identifier: " .. out)
  assert(out:find("fill <", 1, true) ~= nil
    and out:find("<WORKTREE>", #out - 400, true) ~= nil
    and out:find("<BRANCH>", #out - 400, true) ~= nil,
    "the verdict line names the survivors: " .. out:sub(#out - 200))
end

--- The bug this guards: a builder brief once named the item id's
--- leading characters as "the branch" — a plausible-looking KSUID
--- prefix that is not a ref anything resolves, since the real branch
--- (`work/<handle>/<claim>`) is only known once the item is claimed.
--- Matched out of the exact sentence, not just found anywhere in the
--- body — the full id (and so its own leading characters) legitimately
--- appears elsewhere, in `<ITEM_ID>`.
local function test_claimed_builder_brief_names_the_real_branch()
  local s = init_state_repo("brief-builder-branch")
  local _, leaf = root_with_leaf(s)
  give_spec(s, leaf)
  fixture.claim_item(s, leaf, "session-a", BASE)
  local expected = branch_of(s, leaf)
  local code, out = brief_and_capture(s, "builder", leaf)
  assert(code == 0, "a claimed, specced item earns its builder brief")
  local rendered = out:match("It is on branch `([^`]+)`")
  assert(rendered ~= nil, "the brief states the branch it is on: " .. out)
  assert(rendered:match("^work/[^/]+/[^/]+$") ~= nil,
    "the branch is work/<handle>/<claim> shaped: " .. tostring(rendered))
  assert(rendered == expected,
    "the brief names the claim's actual branch: " .. tostring(rendered))
  assert(rendered ~= leaf:sub(1, 8),
    "the branch is never the item id's leading characters: " .. tostring(rendered))
  assert(out:find("<BRANCH>", 1, true) == nil,
    "the branch placeholder is filled once the item is claimed")
end

local function test_research_brief_recommends_rather_than_writes()
  local s = init_state_repo("brief-research")
  local _, leaf = root_with_leaf(s)
  give_spec(s, leaf)
  local code, out = brief_and_capture(s, "research", leaf)
  assert(code == 0, "a specced item earns its research brief")
  assert(out:find(leaf, 1, true) ~= nil, "the full id rides the brief")
  assert(out:find("Do exactly this.", 1, true) ~= nil,
    "the spec sidecar rides verbatim")
  assert(out:find("ignore that instruction", 1, true) ~= nil,
    "the research brief tells the agent to recommend, not to write the board, "
    .. "even when the item's own spec says otherwise")
  assert(out:find("never open a PR", 1, true) ~= nil,
    "the rules say plainly: no PR")
  assert(out:find("Open a PR", 1, true) == nil
    and out:find("git push", 1, true) == nil,
    "a research slice has no diff, so no push/PR step")
  assert(out:find("<WORKTREE>", 1, true) ~= nil,
    "what the board cannot answer survives the fill")
end

local function test_review_brief_needs_the_handover()
  local s = init_state_repo("brief-review")
  local _, leaf = root_with_leaf(s)
  give_spec(s, leaf)
  assert(brief.cmd_brief(s, "review", leaf) ~= 0,
    "no commit recorded, no review brief — the handover is what a review judges")
  handover(s, leaf, "https://example.test/change/42")
  reclaim(s, leaf, "session-b")
  local code, out = brief_and_capture(s, "review", leaf)
  assert(code == 0, "the recorded commit unlocks the review brief")
  assert(out:find(HEAD, 1, true) ~= nil, "the exact commit is filled")
  assert(flat_text(out):find(flat_text(stale_board_sentence(s)), 1, true) ~= nil,
    "the review names the stale board checkout and fills its path")
  assert(out:find("<BOARD_DIR>", 1, true) == nil,
    "the review fills the board directory placeholder")
  assert(out:find("https://example.test/change/42", 1, true) ~= nil,
    "the optional navigation URL is filled")
  assert(out:find("--pr", 1, true) == nil, "no provider identifier is evidence")
  assert(out:find("bin/gitboard", 1, true) == nil,
    "no caller-supplied invocation, so no guessed product-checkout "
    .. "bin/gitboard either: " .. out)
  assert(out:find(gitinvocation.UNRESOLVED .. " verdict", 1, true) ~= nil,
    "the verdict command uses the explicit unresolved sentinel instead: " .. out)
  assert(out:find("<PRODUCT_ROOT>", 1, true) == nil,
    "the review no longer carries a PRODUCT_ROOT-based invocation at all: " .. out)
  assert(out:find("<REVIEW_SESSION>", 1, true) == nil,
    "the placeholder is gone — the brief fills the claim's own session")
  local label = "session-b"
  assert(out:find("session `" .. label .. "`", 1, true) ~= nil,
    "the review is told the exact session it is claimed under: " .. out)
  assert(out:find("--session " .. label, 1, true) ~= nil,
    "and records its verdict under the same string")
  assert(out:find("claimed under session " .. label, 1, true) ~= nil,
    "the verdict line repeats it, so the reviewer reads the exact claim "
    .. "the board already holds")
end

-- `PRODUCT_ROOT` is `GITBOARD_DIR`'s parent's parent — the checkout root
-- `bin/gitboard` itself execs from, since it exports `GITBOARD_DIR` as
-- `<root>/o/board` before handing off to the pinned binary. This fixture
-- configures no `gitboard.repository` mapping for "acme/widgets", so
-- `<WORKTREE>` cannot be derived and survives — PRODUCT_ROOT resolving
-- is independent of that. It no longer supplies the GitBoard invocation
-- itself either — that is `<GITBOARD_CMD>`, unresolved here since no
-- caller command was given.
local function test_product_root_fills_from_gitboard_dir()
  local s = init_state_repo("brief-product-root")
  local _, leaf = root_with_leaf(s)
  give_spec(s, leaf)
  handover(s, leaf)
  reclaim(s, leaf, "session-b")
  local prior = env.get("GITBOARD_DIR")
  check.must(env.set("GITBOARD_DIR", fs.join(PRODUCT_ROOT, "o/board")))
  local code, out = brief_and_capture(s, "review", leaf)
  if prior == nil then local _ok, _err = env.unset("GITBOARD_DIR")
  else check.must(env.set("GITBOARD_DIR", prior)) end
  assert(code == 0, "the recorded commit unlocks the review brief")
  assert(out:find("<PRODUCT_ROOT>", 1, true) == nil,
    "PRODUCT_ROOT (from GITBOARD_DIR) still fills: " .. out)
  assert(out:find("<WORKTREE>", 1, true) ~= nil,
    "no repository mapping is configured, so the worktree path cannot "
    .. "be derived and the placeholder survives: " .. out)
  assert(out:find("bin/gitboard", 1, true) == nil,
    "still no guessed product-checkout bin/gitboard: " .. out)
  assert(out:find(gitinvocation.UNRESOLVED, 1, true) ~= nil,
    "GITBOARD_CMD is unresolved on its own — no caller command was given: " .. out)
end

-- A brief trusts the exact handover commit and never reads provider check
-- state. The caller may inspect checks externally before passing it on.
local function test_commit_handover_fills_head_without_provider_state()
  local s = init_state_repo("brief-commit-head")
  local _, leaf = root_with_leaf(s)
  give_spec(s, leaf)
  handover(s, leaf)
  reclaim(s, leaf, "session-b")
  local code, out = brief_and_capture(s, "review", leaf)
  assert(code == 0)
  assert(out:find(HEAD, 1, true) ~= nil and out:find("<HEAD_SHA>", 1, true) == nil,
    "the board's exact commit is the only evidence: " .. out)
  assert(out:find("CI is read from", 1, true) == nil
    and out:find("performs the GitHub side", 1, true) == nil,
    "the brief performs no provider observation: " .. out)
end

local function test_brief_refusals_and_the_spec_less_decompose()
  local s = init_state_repo("brief-refusals")
  local root, leaf = root_with_leaf(s)
  assert(brief.cmd_brief(s, "pilot", leaf) ~= 0,
    "an unknown kind is refused, not guessed")
  assert(brief.cmd_brief(s, "builder", leaf) ~= 0,
    "a builder brief without a spec would build an interpretation")
  local code, out = brief_and_capture(s, "decompose", root)
  assert(code == 0, "a spec-less outcome still decomposes")
  assert(out:find("(the item has no spec sidecar)", 1, true) ~= nil,
    "and says so in place of the spec")
  local it = check.must(store.load(s, leaf))
  assert(it.claim == "", "brief is a read: no claim moved")
  assert(out:find("bin/gitboard sync", 1, true) ~= nil
    and out:find("o/bin/gitboard", 1, true) == nil
    and out:find("gitboard is already built", 1, true) == nil,
    "decompose brief names bin/gitboard, drops o/bin/gitboard and the "
    .. "stale 'already built' sentence: " .. out)
  local prior = env.get("GITBOARD_DIR")
  check.must(env.set("GITBOARD_DIR", fs.join(PRODUCT_ROOT, "o/board")))
  local _, dout = brief_and_capture(s, "decompose", root)
  if prior == nil then local _ok, _err = env.unset("GITBOARD_DIR")
  else check.must(env.set("GITBOARD_DIR", prior)) end
  assert(dout:find("cd " .. PRODUCT_ROOT .. "\n", 1, true) ~= nil,
    "decompose: PRODUCT_ROOT fills from GITBOARD_DIR: " .. dout)
end

local function test_refine_brief_carries_the_current_spec_as_base()
  local s = init_state_repo("brief-refine")
  local _, leaf = root_with_leaf(s)
  give_spec(s, leaf)
  local code, out = brief_and_capture(s, "refine", leaf)
  assert(code == 0)
  assert(out:find("compare-and-swap base", 1, true) ~= nil
    and out:find("Do exactly this.", 1, true) ~= nil,
    "the current spec rides as the CAS base")
  assert(out:find("<GAP>", 1, true) ~= nil,
    "the gap paragraph stays the orchestrator's to fill")
  assert(out:find("bin/gitboard sync", 1, true) ~= nil
    and out:find("o/bin/gitboard", 1, true) == nil
    and out:find("gitboard is already built", 1, true) == nil,
    "refine brief names bin/gitboard, drops o/bin/gitboard and the "
    .. "stale 'already built' sentence: " .. out)
  local prior = env.get("GITBOARD_DIR")
  check.must(env.set("GITBOARD_DIR", fs.join(PRODUCT_ROOT, "o/board")))
  local _, rout = brief_and_capture(s, "refine", leaf)
  if prior == nil then local _ok, _err = env.unset("GITBOARD_DIR")
  else check.must(env.set("GITBOARD_DIR", prior)) end
  assert(rout:find("cd " .. PRODUCT_ROOT .. "\n", 1, true) ~= nil,
    "refine: PRODUCT_ROOT fills from GITBOARD_DIR: " .. rout)
end
-- Legacy research metadata is readable, but only an exact head earns review.
local function test_review_brief_refuses_a_result_only_handover()
  local s = init_state_repo("brief-research-review")
  local _, leaf = root_with_leaf(s)
  give_spec(s, leaf)
  research_handover(s, leaf)
  local code, out = brief_and_capture(s, "review", leaf)
  assert(code ~= 0, "a result-only handover cannot earn review")
  assert(out:find("has a legacy research result but no commit handover", 1, true) ~= nil, out)
  assert(out:find("take " .. leaf:sub(1, 8) .. " --head SHA", 1, true) ~= nil, out)
end

--- `s` with every run of whitespace collapsed to one space, so a
--- sentence pinned here reads the same whether the text wraps it
--- across one line or several — the same helper `_work.brieftext_test`
--- uses to pin BUILDER's own wrapped sentences.
--- @param s string The text to flatten
--- @return string The flattened text
local function flat(s: string): string
  return (s:gsub("%s+", " "))
end

-- The friction ask rides after EVERY kind's own "Final report"
-- section, unconditionally — one `find` per kind, so no orchestrator
-- can spawn a brief that omits it the way the friction log this item
-- is evidence for once did by hand.
local function test_every_kind_carries_the_friction_ask()
  local opener = flat(brieftext_friction.ASK):match("^([^.]+%.)")
  local s = init_state_repo("brief-friction")
  local root, leaf = root_with_leaf(s)
  give_spec(s, leaf)
  for _, kind in ipairs({"builder", "research", "refine"}) do
    local code, out = brief_and_capture(s, kind, leaf)
    assert(code == 0, kind .. " brief: " .. out)
    assert(flat(out):find(opener, 1, true) ~= nil,
      kind .. " brief must carry the friction ask: " .. out)
  end
  local dcode, dout = brief_and_capture(s, "decompose", root)
  assert(dcode == 0, "decompose brief: " .. dout)
  assert(flat(dout):find(opener, 1, true) ~= nil,
    "decompose brief must carry the friction ask: " .. dout)
  handover(s, leaf)
  reclaim(s, leaf, "session-b")
  local rcode, rout = brief_and_capture(s, "review", leaf)
  assert(rcode == 0, "review brief: " .. rout)
  assert(flat(rout):find(opener, 1, true) ~= nil,
    "review brief must carry the friction ask: " .. rout)
end
