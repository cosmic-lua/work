#!/usr/bin/env cosmic
-- `worktree`: branches, adds a worktree beside a local checkout, and
-- bootstraps it. Every test drives it against `--root DIR` naming a
-- fixture checkout directly, bypassing the sibling-checkout search —
-- exactly how a test with no real sibling layout to fake uses it.

local child = require("cosmic.child")
local env = require("cosmic.env")
local fs = require("cosmic.fs")
local fixture = require("_work.fixture")
local graph = require("_work.gitgraph")
local store = require("_work.store")
local worktree = require("_work.gitworktree")

local git = fixture.git
local tmpdir = fixture.tmpdir

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
  return checkout, base
end

--- A sibling pair beside one fixture base: `sibling` is a real
--- checkout cloned from a bare repo placed at a path ENDING in
--- `github.com/<slug>.git` — a real, fetchable local path whose
--- string still matches `resolve_checkout`'s own `github%.com[:/]`
--- parse verbatim once cloned, with no URL-rewrite trick needed —
--- `invoking` carries only `bin/gitboard`, no git repo of its own, the
--- anchor `invoking_checkout` finds via `GITBOARD_DIR`.
--- @param name string A unique fixture name
--- @param slug string The `owner/name` `sibling`'s origin should read as
--- @return string The sibling checkout's absolute path
--- @return string The invoking (product-root) directory's absolute path
local function make_sibling_checkout(name: string, slug: string): string, string
  local base = fs.join(tmpdir, "wt-sib-" .. name)
  assert(fs.remove_all(base))
  assert(fs.make_dirs(base))
  local bare = fs.join(base, "remotes/github.com", slug .. ".git")
  assert(fs.make_dirs(fs.dirname(bare)))
  git(base, {"init", "-q", "--bare", bare})
  local seed = fs.join(base, "seed")
  git(base, {"clone", "-q", bare, seed})
  git(seed, {"checkout", "-q", "-b", "main"})
  assert(fs.write(fs.join(seed, "README"), "seed\n"))
  git(seed, {"add", "-A"})
  git(seed, {"commit", "-q", "-m", "seed"})
  git(seed, {"push", "-q", "origin", "main"})
  local sibling = fs.join(base, "sibling-checkout")
  git(base, {"clone", "-q", bare, sibling})
  git(sibling, {"checkout", "-q", "main"})
  local invoking = fs.join(base, "product-root")
  assert(fs.make_dirs(fs.join(invoking, "bin")))
  assert(fs.write(fs.join(invoking, "bin/gitboard"), ""))
  return sibling, invoking
end

--- `f`, with `GITBOARD_DIR` pointed at `<invoking>/o/board` for its
--- duration — `invoking_checkout`'s own dirname-dirname guess — then
--- restored, whatever it was before.
--- @param invoking string The fixture's own product-root directory
--- @param f function(): boolean The test body; returns true when done
local function with_invoking_checkout(invoking: string, f: function(): boolean)
  local prior = env.get("GITBOARD_DIR")
  assert(env.set("GITBOARD_DIR", fs.join(invoking, "o/board")))
  local ok, err = pcall(f)
  if prior == nil then local _ok, _err = env.unset("GITBOARD_DIR")
  else assert(env.set("GITBOARD_DIR", prior)) end
  if not ok then
    error(err, 0)
  end
end

--- A workable item carrying a `repo`/`base` — `worktree` refuses one
--- with no repo, and needs a base to branch off of.
--- @param name string A unique fixture name
--- @return store.Store, string The board and the item's id
local function item_with_repo(name: string): store.Store, string
  local s = fixture.init_state_repo(name)
  local _root, leaf = fixture.root_with_leaf(s)
  assert(graph.cmd_set(s, leaf, nil, "acme/widgets", "main") == 0)
  return s, leaf
end

-- The happy path: a branch and worktree appear beside the checkout,
-- never nested inside it, and the verdict line names the path.
local function test_worktree_creates_branch_and_path()
  local checkout = make_checkout("happy", "none")
  local s, leaf = item_with_repo("wt-happy")
  local id8 = leaf:sub(1, 8)
  local expect = fs.join(fs.dirname(checkout), "wt", id8)
  assert(worktree.cmd_worktree(s, leaf, checkout, {}) == 0)
  assert(fs.is_dir(expect), "the worktree exists at the sibling path")
  assert(fs.is_file(fs.join(expect, "README")), "checked out from main")
  local r = assert(child.run({"git", "rev-parse", "--abbrev-ref", "HEAD"},
      {cwd = expect}))
  assert((r.stdout:gsub("%s+$", "")) == id8,
    "branched under the item id's first 8 characters: " .. r.stdout)
end

-- Never reuses a worktree: an existing branch or path both refuse a
-- second call outright, rather than silently reusing either.
local function test_worktree_refuses_a_repeat()
  local checkout = make_checkout("repeat", "none")
  local s, leaf = item_with_repo("wt-repeat")
  assert(worktree.cmd_worktree(s, leaf, checkout, {}) == 0)
  assert(worktree.cmd_worktree(s, leaf, checkout, {}) ~= 0,
    "a second call over the same branch and path refuses")
end

-- Each `--ref` lands in the worktree as `refs/spike/<basename>` —
-- fetched AFTER the (stubbed) bootstrap, so its own `--make fetch`
-- cannot clobber it — named from the ref's last path segment even
-- when the ref itself is nested (`notes/spike` lands at
-- `refs/spike/spike`, not `refs/spike/notes/spike`).
local function test_worktree_fetches_each_ref()
  local checkout, base = make_checkout("ref", "cosmic")
  git(checkout, {"fetch", "origin", "main"})
  git(checkout, {"checkout", "-q", "-b", "notes/spike", "origin/main"})
  assert(fs.write(fs.join(checkout, "SPIKE"), "spike content\n"))
  git(checkout, {"add", "SPIKE"})
  git(checkout, {"commit", "-q", "-m", "spike"})
  git(checkout, {"push", "-q", "origin", "notes/spike"})
  git(checkout, {"checkout", "-q", "main"})
  git(checkout, {"branch", "-q", "-D", "notes/spike"})
  local s, leaf = item_with_repo("wt-ref")
  local id8 = leaf:sub(1, 8)
  local expect = fs.join(fs.dirname(checkout), "wt", id8)
  local prior = env.get("GITBOARD_WORKTREE_BOOTSTRAP")
  assert(env.set("GITBOARD_WORKTREE_BOOTSTRAP", "0"))
  local ok, err = pcall(function(): boolean
      assert(worktree.cmd_worktree(s, leaf, checkout, {"notes/spike"}) == 0)
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
  local s, leaf = item_with_repo("wt-cosmic")
  local id8 = leaf:sub(1, 8)
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
      assert(worktree.cmd_worktree(s, leaf, checkout, {}) == 0)
      return true
    end)
  _G.print = old_print
  if prior == nil then local _ok, _err = env.unset("GITBOARD_WORKTREE_BOOTSTRAP")
  else assert(env.set("GITBOARD_WORKTREE_BOOTSTRAP", prior)) end
  if not ok then
    error(err, 0)
  end
  local out = table.concat(lines, "\n")
  assert(out:find("bootstrapped cosmic", 1, true) ~= nil,
    "the verdict still names the detected tree kind: " .. out)
  assert(not fs.is_file(fs.join(base, "bootstrap_ran")),
    "the stub never actually ran bin/cosmic")
  local wt = fs.join(fs.dirname(checkout), "wt", id8)
  assert(fs.is_file(fs.join(wt, "bin/cosmic")), "the tree carries bin/cosmic")
end

-- No repo, no resolution attempted: the refusal names the gap rather
-- than trying (and failing more confusingly) to resolve "".
local function test_worktree_refuses_with_no_repo()
  local s = fixture.init_state_repo("wt-norepo")
  local _root, leaf = fixture.root_with_leaf(s)
  assert(worktree.cmd_worktree(s, leaf, "", {}) ~= 0,
    "an item with no repo set is refused")
end

-- A cosmopolitan tree (a `third_party/lua` marker, no `bin/cosmic`)
-- bootstraps to nothing — its own gate is the builder's first.
local function test_worktree_bootstrap_detects_cosmopolitan_tree()
  local checkout = make_checkout("cosmopolitan", "cosmopolitan")
  local s, leaf = item_with_repo("wt-cosmopolitan")
  assert(worktree.cmd_worktree(s, leaf, checkout, {}) == 0)
end

-- With no `--root`, `worktree` resolves the item's repo on its own:
-- the invoking checkout's own origin does not match, so it walks its
-- siblings and lands on the one whose origin does.
local function test_worktree_resolves_checkout_via_sibling_search()
  local sibling, invoking = make_sibling_checkout("resolve", "acme/widgets")
  local s, leaf = item_with_repo("wt-resolve")
  local id8 = leaf:sub(1, 8)
  local expect = fs.join(fs.dirname(sibling), "wt", id8)
  with_invoking_checkout(invoking, function(): boolean
      assert(worktree.cmd_worktree(s, leaf, "", {}) == 0)
      assert(fs.is_dir(expect),
        "auto-resolved via the sibling whose origin matches the repo")
      return true
    end)
end

-- No sibling answers the item's repo: the refusal names the URL to
-- clone rather than guessing at a checkout that is not there.
local function test_worktree_refuses_when_no_sibling_matches()
  local _sibling, invoking = make_sibling_checkout("norefuse", "acme/widgets")
  local s = fixture.init_state_repo("wt-norefuse")
  local _root, leaf = fixture.root_with_leaf(s)
  assert(graph.cmd_set(s, leaf, nil, "someone/else", "main") == 0)
  with_invoking_checkout(invoking, function(): boolean
      local code = worktree.cmd_worktree(s, leaf, "", {})
      assert(code ~= 0, "no local checkout answers someone/else")
      return true
    end)
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
  local s = fixture.init_state_repo("wt-cosmobase")
  local _root, leaf = fixture.root_with_leaf(s)
  assert(graph.cmd_set(s, leaf, nil, "acme/cosmopolitan-lua-fork", nil) == 0)
  local id8 = leaf:sub(1, 8)
  assert(worktree.cmd_worktree(s, leaf, checkout, {}) == 0)
  local expect = fs.join(fs.dirname(checkout), "wt", id8)
  assert(fs.is_dir(expect), "branched off master, the cosmopolitan default")
end
