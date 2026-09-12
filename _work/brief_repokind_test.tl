#!/usr/bin/env cosmic
-- `_work.brief` fills `<TYPE_CHECK_CMD>`, `<TEST_CMD>`, `<GATE_CMD>`, and
-- `<BOOTSTRAP_CMD>` from the item's resolved repo kind
-- (`_work.repoprofile` via `_work.briefcommands`), never a hardcoded
-- `bin/cosmic`/`make` fact named inline by repo. Three fixtures: a
-- `cosmic`-kind checkout earns the resolved cosmic commands, a
-- `make`-kind checkout earns its own declared targets, and an
-- unresolvable repo falls back to the exact literal text the templates
-- carried before this module existed — the regression guard for
-- `cosmic-lua/cosmic` and, until its own Makefile advertises the four
-- targets, `cosmic-lua/cosmopolitan`.

local check = require("cosmic.check")
local fixture = require("_work.fixture")
local fs = require("cosmic.fs")
local brief = require("_work.brief")
local item = require("_work.item")
local store = require("_work.store")
local storewrite = require("_work.storewrite")

local init_state_repo = fixture.init_state_repo
local give_spec = fixture.give_spec
local root_with_leaf = fixture.root_with_leaf
local git = fixture.git

local BASE < const > = ("a"):rep(40)

--- Put an item in the v3 commit-handover shape without involving a
--- provider — the same shape `_work.brief_test`'s own `handover` builds.
local function handover(s: store.Store, id: string)
  fixture.claim_item(s, id, "session-a", BASE)
  local it = check.must(store.load(s, id))
  it.repo = "acme/widgets"
  it.handover_head = ("b"):rep(40)
  assert(item.record_involvement(it.builders, "session-a"))
  assert(storewrite.save(s, it, "take " .. id:sub(1, 8) .. " by session-a"))
end

local function reclaim(s: store.Store, id: string, session: string)
  fixture.drop_claim(s, id, "session-a", "handed over")
  fixture.claim_item(s, id, session, BASE)
end

--- A fresh local git checkout carrying only the marker file
--- `_work.repoprofile` looks for: `bin/cosmic` for a `cosmic` kind, a
--- `.PHONY`-advertising `Makefile` for a `make` kind, neither for an
--- unresolvable repo.
--- @param name string Unique fixture name
--- @param kind string "cosmic", "make", or "absent"
--- @return string The checkout's absolute path
local function make_checkout(name: string, kind: string): string
  local root = fs.join(fixture.tmpdir, "brief-repokind-" .. name)
  assert(fs.remove_all(root) and fs.make_dirs(root))
  git(root, {"init", "-q"})
  if kind == "cosmic" then
    assert(fs.make_dirs(fs.join(root, "bin")))
    assert(fs.write(fs.join(root, "bin/cosmic"), ""))
  elseif kind == "make" then
    assert(fs.write(fs.join(root, "Makefile"),
        ".PHONY: bootstrap gate check-file test-file\n"))
  end
  assert(fs.write(fs.join(root, "README"), "seed\n"))
  git(root, {"add", "-A"})
  git(root, {"commit", "-q", "-m", "seed"})
  return root
end

--- Map "acme/widgets" to `checkout` for this board's own local Git config
--- — the same `gitboard.repository` mapping `_work.repository_map`
--- resolves and `_work.gitworktree_bootstrap_test` configures the same way.
local function map_repo(s: store.Store, checkout: string)
  git(s.root, {"config", "--local", "--add", "gitboard.repository",
      "acme/widgets=" .. checkout})
end

local function set_repo(s: store.Store, id: string)
  local it = check.must(store.load(s, id))
  it.repo = "acme/widgets"
  assert(storewrite.save(s, it, "set repo"))
end

--- Run brief.cmd_brief and capture exactly what it prints via
--- print() — the swap-and-restore pattern `_work.brief_test` uses.
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
  if not ok then error(result, 0) end
  return result, table.concat(lines, "\n")
end

--- Every run of whitespace collapsed to one space, so a sentence pinned
--- here reads the same whether the template wraps it across one line
--- or several — the same helper `_work.brieftext_test` uses.
local function flat(s: string): string
  return (s:gsub("%s+", " "))
end

local function test_builder_and_review_fill_cosmic_resolved_commands()
  local s = init_state_repo("brief-repokind-cosmic")
  local _, leaf = root_with_leaf(s)
  give_spec(s, leaf)
  local checkout = make_checkout("cosmic", "cosmic")
  map_repo(s, checkout)
  set_repo(s, leaf)

  local code, out = brief_and_capture(s, "builder", leaf)
  assert(code == 0, out)
  local flat_out = flat(out)
  assert(flat_out:find("Between edits, `bin/cosmic --check types <file>`", 1, true) ~= nil,
    "the resolved cosmic check-file command fills TYPE_CHECK_CMD: " .. out)
  assert(flat_out:find(
      "test file (`bin/cosmic --make test _build/<name>_test.tl`)", 1, true) ~= nil,
    "the resolved cosmic test-file command fills TEST_CMD: " .. out)
  assert(flat_out:find("confirm it is green (`bin/cosmic --make ci`)", 1, true) ~= nil,
    "the resolved cosmic gate command fills GATE_CMD: " .. out)
  assert(flat_out:find("run `bin/cosmic --make build` once before", 1, true) ~= nil,
    "BOOTSTRAP_CMD is the resolved plan's own last (build) step: " .. out)
  assert(out:find("for cosmopolitan", 1, true) == nil,
    "a resolved cosmic kind never renders the cosmopolitan fallback branch: " .. out)

  handover(s, leaf)
  reclaim(s, leaf, "session-b")
  local rcode, rout = brief_and_capture(s, "review", leaf)
  assert(rcode == 0, rout)
  local flat_rout = flat(rout)
  assert(flat_rout:find(
      "run the ONE test file that guards it (`bin/cosmic --make test <file>`)",
      1, true) ~= nil,
    "the two-repo (cosmic, work) enumeration collapses to one resolved "
    .. "TEST_CMD: " .. rout)
  assert(flat_rout:find(
      "run `bin/cosmic --make fetch` and `bin/cosmic --make build` before "
      .. "you run any test", 1, true) ~= nil,
    "BOOTSTRAP_CMD for a fresh review checkout is the whole plan: " .. rout)
end

local function test_builder_fills_make_kind_targets()
  local s = init_state_repo("brief-repokind-make")
  local _, leaf = root_with_leaf(s)
  give_spec(s, leaf)
  local checkout = make_checkout("make", "make")
  map_repo(s, checkout)
  set_repo(s, leaf)

  local code, out = brief_and_capture(s, "builder", leaf)
  assert(code == 0, out)
  local flat_out = flat(out)
  -- `make`'s file argument is the `FILE=<file>` variable convention
  -- `_work.repoprofile`'s own `check_file`/`test_file` build, not a
  -- positional argument like `cosmic`'s — verified runnable by hand
  -- against a real Makefile carrying these targets (`make -f Makefile
  -- check-file FILE=foo.tl` runs the target; the bare-positional form
  -- this test asserted before this fix does not: "No rule to make
  -- target 'foo.tl'").
  assert(flat_out:find(
      "Between edits, `make -f Makefile check-file FILE=<file>`", 1, true) ~= nil,
    "a make-kind repo's own check-file target fills TYPE_CHECK_CMD "
    .. "with its FILE= convention, not a bare positional argument: " .. out)
  assert(flat_out:find(
      "test file (`make -f Makefile test-file FILE=_build/<name>_test.tl`)",
      1, true) ~= nil,
    "a make-kind repo's own test-file target fills TEST_CMD "
    .. "with its FILE= convention, not a bare positional argument: " .. out)
  assert(flat_out:find("confirm it is green (`make -f Makefile gate`)", 1, true) ~= nil,
    "a make-kind repo's own gate target fills GATE_CMD: " .. out)
  assert(flat_out:find("run `make -f Makefile bootstrap` once before", 1, true) ~= nil,
    "a make-kind repo's own bootstrap target fills BOOTSTRAP_CMD: " .. out)
  assert(out:find("bin/cosmic", 1, true) == nil,
    "a resolved make kind never renders any cosmic-specific fallback text: " .. out)
end

-- The regression guard: an item whose repo cannot be resolved to any
-- kind (no local checkout mapped) renders the exact literal text every
-- builder and reviewer saw before this module existed — not a
-- behavior change for `cosmic-lua/cosmic` (which always resolves) or,
-- until its own Makefile advertises the four targets, for
-- `cosmic-lua/cosmopolitan`.
local function test_unresolvable_repo_falls_back_to_the_literal_text()
  local s = init_state_repo("brief-repokind-absent")
  local _, leaf = root_with_leaf(s)
  give_spec(s, leaf)
  set_repo(s, leaf) -- no `gitboard.repository` mapping configured at all

  local code, out = brief_and_capture(s, "builder", leaf)
  assert(code == 0, out)
  local flat_out = flat(out)
  assert(flat_out:find("Between edits, `bin/cosmic --check types <file>`", 1, true) ~= nil, out)
  assert(flat_out:find(
      "test file (`bin/cosmic --make test _build/<name>_test.tl`)", 1, true) ~= nil, out)
  assert(flat_out:find(
      "confirm it is green (`bin/cosmic --make ci` for cosmic; "
      .. "`make -j$(nproc) o//tool/lua/test` for cosmopolitan)", 1, true) ~= nil,
    "the two-repo gate enumeration survives unresolved, exactly as today: " .. out)
  assert(flat_out:find("run `--make build` once before", 1, true) ~= nil,
    "the bare --make build fallback survives unresolved, exactly as today: " .. out)

  handover(s, leaf)
  reclaim(s, leaf, "session-b")
  local rcode, rout = brief_and_capture(s, "review", leaf)
  assert(rcode == 0, rout)
  local flat_rout = flat(rout)
  -- Quoted verbatim from `_work/brieftext_review.tl` at base commit
  -- `1a31ae33` (before `_work.briefcommands` existed) — not the collapsed
  -- single-command wording `_work.briefcommands` renders once a repo
  -- resolves, which would pass this guard even if the fallback drifted.
  assert(flat_rout:find(
      "run the ONE test file that guards it "
      .. "(`bin/cosmic --make test <file>` in cosmic, "
      .. "`bin/cosmic --make test _work/<file>` in work), not the suite",
      1, true) ~= nil,
    "the two-branch (cosmic, work) test-file sentence must survive "
    .. "unresolved exactly as base commit 1a31ae33 wrote it: " .. rout)
  assert(flat_rout:find(
      "That checkout has no `o/3p` cache yet — run "
      .. "`bin/cosmic --make fetch` before its first test, and "
      .. "`--make build` once if you run any test.",
      1, true) ~= nil,
    "the fresh-checkout bootstrap sentence must survive unresolved "
    .. "exactly as base commit 1a31ae33 wrote it, fetch-then-build "
    .. "phrasing included, not the resolved-kind paraphrase: " .. rout)
end
