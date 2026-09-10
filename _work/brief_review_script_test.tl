#!/usr/bin/env cosmic
-- Split out of `_work/brief_test.tl`, which sits at the file cap
-- (`AGENTS.md`'s 500-line ceiling) already: the review-template
-- selection this covers — `REVIEW_SCRIPT` for a mechanical diff,
-- `REVIEW` for anything bigger — is `_work.brief`'s, but its own
-- test fixture lives here instead. The survivor-list coverage below
-- lands here for the same file-cap reason (`_work.brieftext`'s own
-- builder-brief step 1 names this as the sanctioned move: an obvious,
-- low-risk seam, this file's own existing split, rather than a fresh
-- one).

local check = require("cosmic.check")
local child = require("cosmic.child")
local env = require("cosmic.env")
local fs = require("cosmic.fs")
local fixture = require("_work.fixture")
local brief = require("_work.brief")
local gitclaim = require("_work.gitclaim")
local gitspec = require("_work.gitspec")
local item = require("_work.item")
local prepared = require("_work.prepared")
local store = require("_work.store")
local storewrite = require("_work.storewrite")

local init_state_repo = fixture.init_state_repo
local give_spec = fixture.give_spec
local root_with_leaf = fixture.root_with_leaf

-- A real `<root>/bin/gitboard` `product_root()`'s dirname-dirname guess
-- can verify — distinct from `_work.brief_test`'s and
-- `_work.brief_rework_test`'s own, so no two files race on the same path.
local PRODUCT_ROOT < const > = fs.join(
  os.getenv("TEST_TMPDIR") or "/tmp", "brief-review-script-product-root")
assert(fs.make_dirs(fs.join(PRODUCT_ROOT, "bin"))
  and fs.write(fs.join(PRODUCT_ROOT, "bin/gitboard"), ""))

--- Run brief.cmd_brief and capture exactly what it prints via
--- print() — the same swap-and-restore pattern `_work/brief_test.tl`'s
--- own `brief_and_capture` uses.
--- @param s store.Store The store
--- @param id string The item id
--- @return integer cmd_brief's exit code
--- @return string Every print()'d line, newline-joined
local function brief_and_capture(s: store.Store, id: string): integer, string
  local old_print = _G.print
  local lines: {string} = {}
  _G.print = function(...: any)
    local parts: {string} = {}
    for i = 1, select("#", ...) do
      parts[i] = tostring((select(i, ...)))
    end
    lines[#lines + 1] = table.concat(parts, "\t")
  end
  local ok, result = pcall(brief.cmd_brief, s, "review", id)
  _G.print = old_print
  if not ok then error(result, 0) end
  return result, table.concat(lines, "\n")
end

local function flat_text(text: string): string
  return (text:gsub("%s+", " "))
end

local function stale_board_sentence(s: store.Store): string
  return "The checkout that holds the board worktree (`"
  .. fs.absolute_path(s.root)
  .. "/..`) is the orchestrator's and is stale by construction; never read, grep or build in it. Your worktree is the only tree."
end

--- The same capture as `brief_and_capture` above, for any `kind` —
--- the survivor-list coverage below needs both `builder` and `review`.
--- @param s store.Store The store
--- @param kind string The brief kind
--- @param id string The item id
--- @return integer cmd_brief's exit code
--- @return string Every print()'d line, newline-joined
local function brief_and_capture_kind(s: store.Store, kind: string,
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
  if not ok then error(result, 0) end
  return result, table.concat(lines, "\n")
end

local function git(root: string, args: {string}): string
  local argv: {string} = {"git", "-c", "user.email=test@example.com",
    "-c", "user.name=test"}
  for _, value in ipairs(args) do argv[#argv + 1] = value end
  local r = check.must(child.run(argv, {cwd = root}))
  assert(r.ok, r.stderr)
  return (r.stdout:gsub("%s+$", ""))
end

--- Make a local product change and record its two exact commits on the item.
local function handover_diff(s: store.Store, id: string, name: string,
    path: string, lines: integer)
  local root = fs.join(os.getenv("TEST_TMPDIR") or "/tmp",
    "brief-review-product-" .. name)
  assert(fs.remove_all(root) and fs.make_dirs(root))
  git(root, {"init", "-q"})
  assert(fs.make_dirs(fs.dirname(fs.join(root, path))))
  assert(fs.write(fs.join(root, path), "base\n"))
  git(root, {"add", path})
  git(root, {"commit", "-q", "-m", "base"})
  local base = git(root, {"rev-parse", "HEAD"})
  local body = "base\n"
  for n = 1, lines do body = body .. ("line %d\n"):format(n) end
  assert(fs.write(fs.join(root, path), body))
  git(root, {"commit", "-q", "-am", "change"})
  local head = git(root, {"rev-parse", "HEAD"})
  git(s.root, {"config", "--local", "--add", "gitboard.repository",
      "acme/widgets=" .. root})
  local target = gitclaim.target_item_ref(id)
  local claimed = gitclaim.prepare_batch({{
        root = s.root, id = id, source_ref = target, target_ref = target,
        remote = "origin", batch = "brief-" .. name,
        caller = "session-a", action = "take", product_base = base,
        force = false, why = "", now = os.time(),
      }})
  assert(claimed.prepared ~= nil,
    claimed.refused[id] or claimed.refused.batch)
  assert(prepared.promote_local(s.root, claimed.prepared.transaction))
  local it = check.must(store.load(s, id))
  it.repo, it.handover_head = "acme/widgets", head
  assert(item.record_involvement(it.builders, "session-a"))
  assert(storewrite.save(s, it,
      ("take %s by session-a head:%s"):format(id:sub(1, 8), head:sub(1, 12))))
  -- A review needs distance from the builder: drop the standing build
  -- claim (an active foreign claim refuses acquisition outright) and
  -- re-claim as the reviewer before a review brief will fill one.
  fixture.drop_claim(s, id, "session-a", "handed over")
  fixture.claim_item(s, id, "session-b", base)
end

-- The selection rule is the spec's own, checked at both ends: a
-- 2-line pin diff (well under 20 changed lines, regardless of the
-- one file's own `.tl` extension) earns the numbered script; a
-- 200-line `.tl` diff outside `*_test.tl` keeps the full adversarial
-- `REVIEW`.
local function test_diff_shape_picks_the_review_template()
  for _, case in ipairs({
      {name = "pin", path = "3p/cosmos/cosmos_pin.tl", lines = 2,
        script = true},
      {name = "tl", path = "cosmic/example.tl", lines = 200,
        script = false},
    }) do
    local s = init_state_repo("brief-review-script-" .. case.name)
    local _, leaf = root_with_leaf(s)
    give_spec(s, leaf)
    handover_diff(s, leaf, case.name, case.path, case.lines)
    local code, out = brief_and_capture(s, leaf)
    assert(code == 0, ("%s: a local commit diff earns the brief: %s")
      :format(case.name, out))
    if case.script then
      assert(out:find("git show", 1, true) ~= nil,
        ("%s: a small diff selects the numbered script: %s")
        :format(case.name, out))
      assert(flat_text(out):find(flat_text(stale_board_sentence(s)), 1, true) ~= nil,
        ("%s: REVIEW_SCRIPT names the stale board checkout and fills its path: %s")
        :format(case.name, out))
      assert(out:find("<BOARD_DIR>", 1, true) == nil,
        ("%s: REVIEW_SCRIPT fills the board directory placeholder: %s")
        :format(case.name, out))
    else
      assert(out:find("fresh-context code reviewer", 1, true) ~= nil,
        ("%s: a big .tl diff keeps the adversarial REVIEW: %s")
        :format(case.name, out))
      assert(out:find("How to review — a numbered script", 1, true) == nil,
        ("%s: REVIEW never carries the script's own heading: %s")
        :format(case.name, out))
    end
  end
end

local INJECTION_SPEC < const > = [[
## Change
An example from another item's own spec, quoted here verbatim as
ordinary prose: `take ID --pr <N>`. The board's own `<REVIEW_SESSION>`
placeholder name, also quoted verbatim, from a note about an older
template.
## Non-goals
Not that.
]]

--- A spec that quotes placeholder-shaped tokens verbatim (`<N>`, the
--- board's own `<REVIEW_SESSION>` name) as ordinary prose — the exact
--- false-positive shape this item exists to fix. Neither token is
--- ever among a template's own declared placeholders, so neither may
--- be reported as still owed: a partly-filled builder brief still
--- names its genuine survivor (`<WORKTREE>`), and a fully-filled
--- review brief — every placeholder its own template declares
--- actually answered — names none at all, even though `<N>` and
--- `<REVIEW_SESSION>` still ride the printed body verbatim.
local function test_verdict_line_ignores_placeholders_quoted_in_the_spec()
  local s = init_state_repo("brief-review-script-injection")
  local _, leaf = root_with_leaf(s)
  local path = fs.join(os.getenv("TEST_TMPDIR") or "/tmp", "injection-spec.md")
  assert(fs.write(path, INJECTION_SPEC))
  assert(gitspec.cmd_spec(s, leaf, path) == 0, "spec should be accepted")

  local code, out = brief_and_capture_kind(s, "builder", leaf)
  assert(code == 0, "an injected spec still earns its builder brief")
  assert(out:find("`take ID --pr <N>`", 1, true) ~= nil,
    "the spec's own quoted example rides verbatim: " .. out)
  local vline = out:match("[^\n]*$")
  assert(vline:find("<N>", 1, true) == nil
    and vline:find("<REVIEW_SESSION>", 1, true) == nil,
    "spec-quoted tokens are never reported as survivors: " .. vline)
  assert(vline:find("<WORKTREE>", 1, true) ~= nil,
    "a genuine survivor still names itself: " .. vline)

  handover_diff(s, leaf, "injection", "proof.txt", 1)
  local prior = env.get("GITBOARD_DIR")
  check.must(env.set("GITBOARD_DIR", fs.join(PRODUCT_ROOT, "o/board")))
  local rcode, rout = brief_and_capture_kind(s, "review", leaf)
  if prior == nil then local _ok, _err = env.unset("GITBOARD_DIR")
  else check.must(env.set("GITBOARD_DIR", prior)) end
  assert(rcode == 0, "the exact handover unlocks the review brief: " .. rout)
  assert(rout:find("`take ID --pr <N>`", 1, true) ~= nil,
    "the spec's own quoted example still rides the fully-filled body: " .. rout)
  assert(rout:find("nothing left to fill", 1, true) ~= nil,
    "every real placeholder answered, so the verdict line names none: " .. rout)
end
