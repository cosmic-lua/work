#!/usr/bin/env cosmic
-- `worktree`: branches, adds a worktree beside a local checkout, and
-- bootstraps it. Every test drives it against `--root DIR` naming a
-- fixture checkout directly, bypassing the sibling-checkout search —
-- exactly how a test with no real sibling layout to fake uses it.

local check = require("cosmic.check")
local child = require("cosmic.child")
local claim = require("_work.claim")
local env = require("cosmic.env")
local fs = require("cosmic.fs")
local fixture = require("_work.fixture")
local graph = require("_work.gitgraph")
local gitclaim = require("_work.gitclaim")
local claimbatch = require("_work.claimbatch")
local prepared = require("_work.prepared")
local refs = require("_work.refs")
local store = require("_work.store")
local worktree = require("_work.gitworktree")

local git = fixture.git
local tmpdir = fixture.tmpdir

-- The session every fixture item is claimed under, except the two
-- cases exercising the claim refusal itself.
local SESSION < const > = "build-fixture-9doI"

--- A bare "origin" with one clone that seeds `main` — a README, plus
--- (by `kind`) a `bin/cosmic` stub (executable, leaves a sentinel
--- rather than doing real work, so a test can tell whether bootstrap
--- actually ran it) or a bare `third_party/lua` marker — and a second
--- clone at `<base>/checkout` to pass as `--root`.
--- @param name string A unique fixture name
--- @param kind string "none" | "cosmic" | "cosmopolitan"
--- @return string The `--root` checkout's absolute path
--- @return string The fixture's own base directory (for the sentinel)
local function make_checkout(name: string, kind: string): string, string
  local base = fs.join(tmpdir, "wt-verb-" .. name)
  assert(fs.remove_all(base))
  assert(fs.make_dirs(base))
  local bare = fs.join(base, "origin.git")
  git(base, {"init", "-q", "--bare", bare})
  local seed = fs.join(base, "seed")
  git(base, {"clone", "-q", bare, seed})
  git(seed, {"checkout", "-q", "-b", "main"})
  assert(fs.write(fs.join(seed, "README"), "seed\n"))
  if kind == "cosmic" then
    assert(fs.make_dirs(fs.join(seed, "bin")))
    assert(fs.write(fs.join(seed, "bin/cosmic"),
        "#!/bin/sh\ntouch \"$(dirname \"$0\")/../../bootstrap_ran\"\n"))
    assert(fs.set_mode(fs.join(seed, "bin/cosmic"), tonumber("755", 8)))
  elseif kind == "cosmopolitan" then
    assert(fs.make_dirs(fs.join(seed, "third_party/lua")))
    assert(fs.write(fs.join(seed, "third_party/lua/lua.c"), ""))
  end
  git(seed, {"add", "-A"})
  git(seed, {"commit", "-q", "-m", "seed"})
  git(seed, {"push", "-q", "origin", "main"})
  local checkout = fs.join(base, "checkout")
  git(base, {"clone", "-q", bare, checkout})
  git(checkout, {"checkout", "-q", "main"})
  git(checkout, {"config", "user.name", "test"})
  git(checkout, {"config", "user.email", "test@example.com"})
  return checkout, base
end

--- A cosmic checkout whose `bin/cosmic` stub actually runs (bootstrap
--- left enabled) and echoes a handful of `compile`/`compile-batch`
--- lines before its build PASS summary — the noise `run_step`'s quiet
--- default drops and `--verbose` streams. The build touches a sentinel
--- at the worktree root so a test can tell it ran even when its output
--- never reaches `print`.
--- @param name string A unique fixture name
--- @return string The `--root` checkout's absolute path
local function make_loud_checkout(name: string): string
  local checkout = make_checkout(name, "cosmic")
  local script = table.concat({
      "#!/bin/sh",
      "here=\"$(cd \"$(dirname \"$0\")\" && pwd)\"",
      "touch \"$here/../build_ran\"",
      "echo 'compile o/bin/cosmic a.tl o/a.lua --include-dir .'",
      "echo 'compile-batch o/bin/cosmic o/.groups/x.compiled o/x --srcs a.tl'",
      "echo 'build: PASS (3 files, 1 binary)'",
    }, "\n") .. "\n"
  assert(fs.write(fs.join(checkout, "bin/cosmic"), script))
  assert(fs.set_mode(fs.join(checkout, "bin/cosmic"), tonumber("755", 8)))
  -- `worktree` branches off `origin/<base>`, not this clone's own working
  -- tree, so the loud stub must land in the remote before it can show up
  -- in a worktree cut from it.
  git(checkout, {"add", "bin/cosmic"})
  git(checkout, {"commit", "-q", "-m", "loud stub"})
  git(checkout, {"push", "-q", "origin", "main"})
  return checkout
end

--- Give `id` a real locally-confirmed claim bridge for worktree tests.
local function claim_as(s: store.Store, id: string, session: string,
    product_base?: string)
  local target = gitclaim.target_item_ref(id)
  local tip = check.must(refs.read_ref(s.root, target))
  local result = gitclaim.prepare_batch({{
        root = s.root, id = id, source_ref = target, target_ref = target,
        remote = "origin", batch = "fixture-" .. id:sub(-8),
        caller = session, action = "take", product_base = product_base or tip,
        force = false, why = "", now = os.time(),
      }})
  assert(result.prepared ~= nil, result.refused[id] or result.refused.batch)
  assert(prepared.promote_local(s.root, result.prepared.transaction))
end

local function branch_of(s: store.Store, id: string): string
  local it = check.must(store.load(s, id))
  local st = check.must(claimbatch.read_state(s.root, it.claim_batch or "", id))
  return claim.branch(id, st.root)
end

--- A workable item carrying a `repo`/`base`, claimed under `SESSION` —
--- `worktree` refuses one with no repo, and needs a base to branch off
--- of, but refuses even sooner over an unclaimed item, so every
--- fixture past that gate needs a claim too.
--- @param name string A unique fixture name
--- @return store.Store, string The board and the item's id
local function item_with_repo(name: string, checkout: string): store.Store, string
  local s = fixture.init_state_repo(name)
  local _root, leaf = fixture.root_with_leaf(s)
  assert(graph.cmd_set(s, leaf, nil, "acme/widgets", "main") == 0)
  local base = assert(child.run({"git", "rev-parse", "HEAD"}, {cwd = checkout}))
  claim_as(s, leaf, SESSION, (base.stdout:gsub("%s+$", "")))
  return s, leaf
end

-- The happy path: a branch and worktree appear beside the checkout,
-- never nested inside it, and the verdict line names the path.
local function test_worktree_creates_branch_and_path()
  local checkout = make_checkout("happy", "none")
  local s, leaf = item_with_repo("wt-happy", checkout)
  local branch = branch_of(s, leaf)
  local expect = fs.join(fs.dirname(checkout), "wt", branch)
  assert(worktree.cmd_worktree(s, leaf, SESSION, checkout, {}, false, false) == 0)
  assert(fs.is_dir(expect), "the worktree exists at the sibling path")
  assert(fs.is_file(fs.join(expect, "README")), "checked out from main")
  local r = assert(child.run({"git", "rev-parse", "--abbrev-ref", "HEAD"},
      {cwd = expect}))
  assert((r.stdout:gsub("%s+$", "")) == branch,
    "branched under the stable claim identity: " .. r.stdout)
end

-- Never reuses a worktree: an existing branch or path both refuse a
-- second call outright, rather than silently reusing either.
local function test_worktree_refuses_a_repeat()
  local checkout = make_checkout("repeat", "none")
  local s, leaf = item_with_repo("wt-repeat", checkout)
  assert(worktree.cmd_worktree(s, leaf, SESSION, checkout, {}, false, false) == 0)
  assert(worktree.cmd_worktree(s, leaf, SESSION, checkout, {}, false, false) ~= 0,
    "a second call over the same branch and path refuses")
end

-- Each caller-prepared `--ref` lands in the worktree as
-- `refs/spike/<basename>`, named from the ref's last path segment even
-- when the ref itself is nested (`notes/spike` lands at
-- `refs/spike/spike`, not `refs/spike/notes/spike`).
local function test_worktree_copies_each_prepared_ref()
  local checkout, base = make_checkout("ref", "cosmic")
  git(checkout, {"fetch", "origin", "main"})
  git(checkout, {"checkout", "-q", "-b", "notes/spike", "origin/main"})
  assert(fs.write(fs.join(checkout, "SPIKE"), "spike content\n"))
  git(checkout, {"add", "SPIKE"})
  git(checkout, {"commit", "-q", "-m", "spike"})
  git(checkout, {"push", "-q", "origin", "notes/spike"})
  git(checkout, {"checkout", "-q", "main"})
  git(checkout, {"branch", "-q", "-D", "notes/spike"})
  local s, leaf = item_with_repo("wt-ref", checkout)
  local expect = fs.join(fs.dirname(checkout), "wt", branch_of(s, leaf))
  local prior = env.get("GITBOARD_WORKTREE_BOOTSTRAP")
  assert(env.set("GITBOARD_WORKTREE_BOOTSTRAP", "0"))
  local ok, err = pcall(function(): boolean
      assert(worktree.cmd_worktree(s, leaf, SESSION, checkout,
          {"refs/remotes/origin/notes/spike"}, false, false) == 0)
      return true
    end)
  if prior == nil then local _ok, _err = env.unset("GITBOARD_WORKTREE_BOOTSTRAP")
  else assert(env.set("GITBOARD_WORKTREE_BOOTSTRAP", prior)) end
  if not ok then
    error(err, 0)
  end
  assert(not fs.is_file(fs.join(base, "bootstrap_ran")),
    "the stub never actually ran bin/cosmic — the ref still landed after it")
  local r = assert(child.run({"git", "show", "refs/spike/spike:SPIKE"}, {cwd = expect}))
  assert(r.ok and r.stdout == "spike content\n",
    "the ref's content reads back from refs/spike/spike: " .. r.stdout .. r.stderr)
end

-- Bootstrap detects a cosmic tree (its own verdict names it) but
-- `GITBOARD_WORKTREE_BOOTSTRAP=0` skips actually running it — the
-- stub `bin/cosmic` would otherwise leave a sentinel of its own.
local function test_worktree_bootstrap_stub_skips_execution()
  local checkout, base = make_checkout("cosmic", "cosmic")
  local s, leaf = item_with_repo("wt-cosmic", checkout)
  local prior = env.get("GITBOARD_WORKTREE_BOOTSTRAP")
  assert(env.set("GITBOARD_WORKTREE_BOOTSTRAP", "0"))
  local old_print = _G.print
  local lines: {string} = {}
  _G.print = function(...: any)
    local parts: {string} = {}
    for i = 1, select("#", ...) do
      parts[i] = tostring((select(i, ...)))
    end
    lines[#lines + 1] = table.concat(parts, "\t")
  end
  local ok, err = pcall(function(): boolean
      assert(worktree.cmd_worktree(s, leaf, SESSION, checkout, {}, false, false) == 0)
      return true
    end)
  _G.print = old_print
  if prior == nil then local _ok, _err = env.unset("GITBOARD_WORKTREE_BOOTSTRAP")
  else assert(env.set("GITBOARD_WORKTREE_BOOTSTRAP", prior)) end
  if not ok then
    error(err, 0)
  end
  local out = table.concat(lines, "\n")
  assert(out:find("bootstrap: cosmic (skipped: GITBOARD_WORKTREE_BOOTSTRAP=0)", 1, true) ~= nil,
    "the verdict still names the detected tree kind: " .. out)
  assert(not fs.is_file(fs.join(base, "bootstrap_ran")),
    "the stub never actually ran bin/cosmic")
  local wt = fs.join(fs.dirname(checkout), "wt", branch_of(s, leaf))
  assert(fs.is_file(fs.join(wt, "bin/cosmic")), "the tree carries bin/cosmic")
end

-- Quiet is the default: a local build's own per-file compile/
-- compile-batch noise never reaches the caller — only its PASS
-- summary line does.
local function test_worktree_quiet_bootstrap_keeps_only_summary_lines()
  local checkout = make_loud_checkout("quiet")
  local s, leaf = item_with_repo("wt-quiet", checkout)
  local old_print = _G.print
  local lines: {string} = {}
  _G.print = function(...: any)
    local parts: {string} = {}
    for i = 1, select("#", ...) do
      parts[i] = tostring((select(i, ...)))
    end
    lines[#lines + 1] = table.concat(parts, "\t")
  end
  local ok, err = pcall(function(): boolean
      assert(worktree.cmd_worktree(s, leaf, SESSION, checkout, {}, false, false) == 0)
      return true
    end)
  _G.print = old_print
  if not ok then
    error(err, 0)
  end
  local out = table.concat(lines, "\n")
  assert(out:find("build: PASS (3 files, 1 binary)", 1, true) ~= nil,
    "build's own summary line reaches the caller: " .. out)
  assert(out:find("compile ", 1, true) == nil,
    "the per-file compile lines are dropped: " .. out)
  assert(out:find("compile-batch", 1, true) == nil,
    "the per-file compile-batch lines are dropped: " .. out)
end

-- --verbose opts back into streaming: the stub still actually runs
-- (its own sentinels prove it), but its output goes straight to the
-- real stdout (inherited) rather than through the caller's own print
-- — none of it, compile noise or PASS lines alike, shows up there.
local function test_worktree_verbose_bootstrap_streams_verbatim()
  local checkout = make_loud_checkout("verbose")
  local s, leaf = item_with_repo("wt-verbose", checkout)
  local wt = fs.join(fs.dirname(checkout), "wt", branch_of(s, leaf))
  local old_print = _G.print
  local lines: {string} = {}
  _G.print = function(...: any)
    local parts: {string} = {}
    for i = 1, select("#", ...) do
      parts[i] = tostring((select(i, ...)))
    end
    lines[#lines + 1] = table.concat(parts, "\t")
  end
  local ok, err = pcall(function(): boolean
      assert(worktree.cmd_worktree(s, leaf, SESSION, checkout, {}, false, true) == 0)
      return true
    end)
  _G.print = old_print
  if not ok then
    error(err, 0)
  end
  assert(fs.is_file(fs.join(wt, "build_ran")), "the build step actually ran")
  local out = table.concat(lines, "\n")
  assert(out:find("compile", 1, true) == nil
    and out:find("PASS (3 files", 1, true) == nil,
    "verbose streams straight to the real stdout, none of it through print: "
    .. out)
end

-- No repo, no resolution attempted: the refusal names the gap rather
-- than trying (and failing more confusingly) to resolve "".
local function test_worktree_refuses_with_no_repo()
  local s = fixture.init_state_repo("wt-norepo")
  local _root, leaf = fixture.root_with_leaf(s)
  claim_as(s, leaf, SESSION)
  assert(worktree.cmd_worktree(s, leaf, SESSION, "", {}, false, false) ~= 0,
    "an item with no repo set is refused")
end

-- A cosmopolitan tree (a `third_party/lua` marker, no `bin/cosmic`)
-- bootstraps to nothing — its own gate is the builder's first.
local function test_worktree_bootstrap_detects_cosmopolitan_tree()
  local checkout = make_checkout("cosmopolitan", "cosmopolitan")
  local s, leaf = item_with_repo("wt-cosmopolitan", checkout)
  assert(worktree.cmd_worktree(s, leaf, SESSION, checkout, {}, false, false) == 0)
end

-- With no `--root`, `worktree` resolves only the explicit repository map.
local function test_worktree_resolves_checkout_via_repository_map()
  local checkout = make_checkout("resolve", "none")
  local s, leaf = item_with_repo("wt-resolve", checkout)
  git(s.root, {"config", "--local", "--add", "gitboard.repository",
      "acme/widgets=" .. checkout})
  local expect = fs.join(fs.dirname(checkout), "wt", branch_of(s, leaf))
  assert(worktree.cmd_worktree(s, leaf, SESSION, "", {}, false, false) == 0)
  assert(fs.is_dir(expect), "resolved via the configured repository map")
end

-- An absent map refuses instead of guessing from sibling layout or remotes.
local function test_worktree_refuses_when_repository_is_unmapped()
  local checkout = make_checkout("norefuse", "none")
  local s = fixture.init_state_repo("wt-norefuse")
  local _root, leaf = fixture.root_with_leaf(s)
  assert(graph.cmd_set(s, leaf, nil, "someone/else", "main") == 0)
  local base = assert(child.run({"git", "rev-parse", "HEAD"}, {cwd = checkout}))
  claim_as(s, leaf, SESSION, (base.stdout:gsub("%s+$", "")))
  local code = worktree.cmd_worktree(s, leaf, SESSION, "", {}, false, false)
  assert(code ~= 0, "an unmapped repository is refused")
end

-- A `cosmopolitan` repo with no `base` set branches off `master`, not
-- `main` — `_work.brief`'s own `<BASE_BRANCH>` rule.
local function test_worktree_defaults_cosmopolitan_repo_to_master()
  local base = fs.join(tmpdir, "wt-verb-cosmobase")
  assert(fs.remove_all(base))
  assert(fs.make_dirs(base))
  local bare = fs.join(base, "origin.git")
  git(base, {"init", "-q", "--bare", bare})
  local seed = fs.join(base, "seed")
  git(base, {"clone", "-q", bare, seed})
  git(seed, {"checkout", "-q", "-b", "master"})
  assert(fs.write(fs.join(seed, "README"), "seed\n"))
  git(seed, {"add", "-A"})
  git(seed, {"commit", "-q", "-m", "seed"})
  git(seed, {"push", "-q", "origin", "master"})
  local checkout = fs.join(base, "checkout")
  git(base, {"clone", "-q", bare, checkout})
  git(checkout, {"checkout", "-q", "master"})
  git(checkout, {"config", "user.name", "test"})
  git(checkout, {"config", "user.email", "test@example.com"})
  local s = fixture.init_state_repo("wt-cosmobase")
  local _root, leaf = fixture.root_with_leaf(s)
  assert(graph.cmd_set(s, leaf, nil, "acme/cosmopolitan-lua-fork", nil) == 0)
  local head = assert(child.run({"git", "rev-parse", "HEAD"}, {cwd = checkout}))
  claim_as(s, leaf, SESSION, (head.stdout:gsub("%s+$", "")))
  assert(worktree.cmd_worktree(s, leaf, SESSION, checkout, {}, false, false) == 0)
  local expect = fs.join(fs.dirname(checkout), "wt", branch_of(s, leaf))
  assert(fs.is_dir(expect), "branched off master, the cosmopolitan default")
end

-- An unclaimed item refuses outright, before any git or network call:
-- no branch, no worktree directory. `take ID` was never run (or was
-- refused) — the evidence this item exists to fix.
local function test_worktree_refuses_when_unclaimed()
  local checkout = make_checkout("unclaimed", "none")
  local s = fixture.init_state_repo("wt-unclaimed")
  local _root, leaf = fixture.root_with_leaf(s)
  assert(graph.cmd_set(s, leaf, nil, "acme/widgets", "main") == 0)
  local id8 = leaf:sub(1, 8)
  local expect = fs.join(fs.dirname(checkout), "wt", id8)
  local old_print = _G.print
  local lines: {string} = {}
  _G.print = function(...: any)
    local parts: {string} = {}
    for i = 1, select("#", ...) do
      parts[i] = tostring((select(i, ...)))
    end
    lines[#lines + 1] = table.concat(parts, "\t")
  end
  local code = worktree.cmd_worktree(s, leaf, SESSION, checkout, {}, false, false)
  _G.print = old_print
  local out = table.concat(lines, "\n")
  assert(code ~= 0, "an unclaimed item is refused")
  assert(out:find("is not claimed by " .. SESSION, 1, true) ~= nil,
    "the refusal names the caller session: " .. out)
  assert(not fs.is_dir(expect), "no worktree directory was created")
  local has_branch = child.run({"git", "rev-parse", "--verify", "--quiet",
      "refs/heads/" .. id8}, {cwd = checkout})
  assert(has_branch == nil or not has_branch.ok,
    "no branch was created in the checkout")
end

-- A claim held by a DIFFERENT session refuses too, naming whose claim
-- it actually is rather than only who was refused.
local function test_worktree_refuses_a_different_sessions_claim()
  local checkout = make_checkout("foreign", "none")
  local s, leaf = item_with_repo("wt-foreign", checkout)
  local branch = branch_of(s, leaf)
  local expect = fs.join(fs.dirname(checkout), "wt", branch)
  local old_print = _G.print
  local lines: {string} = {}
  _G.print = function(...: any)
    local parts: {string} = {}
    for i = 1, select("#", ...) do
      parts[i] = tostring((select(i, ...)))
    end
    lines[#lines + 1] = table.concat(parts, "\t")
  end
  local code = worktree.cmd_worktree(s, leaf, "build-a-different-session",
    checkout, {}, false, false)
  _G.print = old_print
  local out = table.concat(lines, "\n")
  assert(code ~= 0, "a different session's claim is refused")
  assert(out:find(SESSION, 1, true) ~= nil,
    "the refusal names whose claim it is: " .. out)
  assert(not fs.is_dir(expect), "no worktree directory was created")
  local has_branch = child.run({"git", "rev-parse", "--verify", "--quiet",
      "refs/heads/" .. branch}, {cwd = checkout})
  assert(has_branch == nil or not has_branch.ok,
    "no branch was created in the checkout")
end

-- The holder field can remain after the two-hour lease expires. Worktree
-- derives the control timestamp from Git history and refuses that stale field
-- rather than treating it as authorization to work offline.
local function test_worktree_refuses_an_expired_claim()
  local checkout = make_checkout("expired", "none")
  local s = fixture.init_state_repo("wt-expired")
  local _root, leaf = fixture.root_with_leaf(s)
  assert(graph.cmd_set(s, leaf, nil, "acme/widgets", "main") == 0)
  local target = gitclaim.target_item_ref(leaf)
  local base = assert(child.run({"git", "rev-parse", "HEAD"}, {cwd = checkout}))
  local caller = ("a"):rep(32)
  local result = gitclaim.prepare_batch({{
        root = s.root, id = leaf, source_ref = target, target_ref = target,
        remote = "origin", batch = "expired", caller = caller,
        action = "take", product_base = (base.stdout:gsub("%s+$", "")),
        force = false, why = "", now = os.time() - claim.LEASE_S - 1,
      }})
  assert(result.prepared ~= nil, result.refused[leaf] or result.refused.batch)
  local p = result.prepared
  assert(prepared.promote_local(s.root, p.transaction))
  local _closed, _cerr = store.close(s)
  local reopened = check.must(store.open(s.root))
  assert(worktree.cmd_worktree(reopened, leaf, caller, checkout, {}, false,
      false) ~= 0, "an expired claim cannot authorize a worktree")
  local path = fs.join(fs.dirname(checkout), "wt", p.members[1].branch)
  assert(not fs.is_dir(path), "no worktree was created for the expired lease")
end
