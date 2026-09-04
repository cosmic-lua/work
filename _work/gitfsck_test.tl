#!/usr/bin/env cosmic
-- `fsck`: `structural_problems` unit-tested directly over hand-built
-- items (no git at all, for the checks that never survive a real
-- write's own gates — a root with a repo, say), and `cmd_fsck` over
-- two real boards: one healthy, one carrying a beats edge written
-- straight through `store.save` (`gitready`'s own checks are a take
-- gate, not a write gate, so this never touches them).

local check = require("cosmic.check")
local child = require("cosmic.child")
local env = require("cosmic.env")
local fixture = require("_work.fixture")
local fs = require("cosmic.fs")
local fsck = require("_work.gitfsck")
local gitboard = require("_work.gitboard")
local index = require("_work.index")
local item = require("_work.item")
local ksuid = require("_work.ksuid")
local store = require("_work.store")
local tail = require("_work.tail")

local tmpdir = os.getenv("TEST_TMPDIR") or "/tmp"

local init_state_repo = fixture.init_state_repo
local root_with_leaf = fixture.root_with_leaf

--- Run `fsck.cmd_fsck` and capture what it printed, the way
--- `gitboard_test.tl`'s own helper pins a CLI verb's console output.
--- @param s store.Store The store
--- @return integer Exit code
--- @return string Every print()'d line, newline-joined
local function fsck_and_capture(s: store.Store): integer, string
  local old_print = _G.print
  local lines: {string} = {}
  _G.print = function(...: any)
    local parts: {string} = {}
    for i = 1, select("#", ...) do
      parts[i] = tostring((select(i, ...)))
    end
    lines[#lines + 1] = table.concat(parts, "\t")
  end
  local code = fsck.cmd_fsck(s)
  _G.print = old_print
  return code, table.concat(lines, "\n")
end

-- A healthy board — one placed root, one workable leaf, nothing
-- flagged — has no problems and says so, item count included.
local function test_a_healthy_board_has_no_problems()
  local s = init_state_repo("fsck-healthy")
  local _root, _leaf = root_with_leaf(s)
  local code, printed = fsck_and_capture(s)
  assert(code == 0, printed)
  assert(printed == "gitboard-fsck: ok (3 items)",
    "root, peer, leaf: 3 items, nothing else printed — got: " .. printed)
end

-- A beats edge naming an id that is not an item — written straight
-- through `store.save`, never through a verb, since `_work.gitready`'s
-- own dangling-blocker check is a TAKE gate, never a write gate — is
-- exactly what `fsck` exists to catch: nothing else on the board ever
-- asks this question.
-- A branch under the item namespace that is not a KSUID is a stray:
-- every read skips it and fsck names it.
local function test_a_stray_branch_under_items_is_named_and_skipped()
  local s = fixture.init_state_repo("fsck-stray")
  fixture.file_item(s, "a real item", "")
  local before = #check.must(store.list(s))
  fixture.git(s.root, {"update-ref", "refs/heads/items/not-an-id", "refs/heads/board/format"})
  assert(#check.must(store.list(s)) == before, "a stray branch is not an item")
  local code, out = fsck_and_capture(s)
  assert(code ~= 0, "fsck refuses a board with a stray branch")
  assert(out:find("stray ref refs/heads/items/not-an-id", 1, true), out)
end

local function test_a_dangling_beats_edge_is_caught()
  local s = init_state_repo("fsck-dangling-beats")
  local root, _leaf = root_with_leaf(s)
  local ghost = check.must(ksuid.encode(1690000001, ("\2"):rep(16)))
  local it = check.must(store.load(s, root))
  it.beats = {ghost}
  assert(store.save(s, it, "hand-edited beats"))
  local code, printed = fsck_and_capture(s)
  assert(code ~= 0, "a dangling beats edge is a problem: " .. printed)
  assert(printed:find("beats " .. ghost, 1, true) ~= nil, printed)
  assert(printed:find("which is not an item", 1, true) ~= nil, printed)
  assert(printed:find("gitboard-fsck: 1 problem(s)", 1, true) ~= nil, printed)
end

-- An edge kind this build does not interpret — `edges/relates/<id>`,
-- say — round-trips through `_work.itemtree` opaquely
-- (`item.Item.other_edges`) and is exactly what `fsck` flags: the kind
-- itself as unknown, and any id under it that names no item.
local function test_an_unknown_edge_kind_is_caught()
  local s = init_state_repo("fsck-unknown-kind")
  local root, _leaf = root_with_leaf(s)
  local ghost = check.must(ksuid.encode(1690000004, ("\5"):rep(16)))
  local it = check.must(store.load(s, root))
  it.other_edges = {relates = {[ghost] = ""}}
  assert(store.save(s, it, "hand-edited other_edges"))
  local reread = check.must(store.load(s, root))
  local reread_edges = reread.other_edges
  assert(reread_edges ~= nil and reread_edges.relates ~= nil
    and reread_edges.relates[ghost] ~= nil, "the kind round-trips")
  local code, printed = fsck_and_capture(s)
  assert(code ~= 0, "an unknown edge kind is a problem: " .. printed)
  assert(printed:find("unknown edge kind relates", 1, true) ~= nil, printed)
  assert(printed:find("relates names " .. ghost, 1, true) ~= nil, printed)
  assert(printed:find("which is not an item", 1, true) ~= nil, printed)
end

--- A minimal valid item.
--- @param over {string: any} Fields to override
--- @return item.Item The item
local function make_item(over?: {string: any}): item.Item
  local t: {string: any} = {
    id = check.must(ksuid.encode(1690000002, ("\3"):rep(16))), title = "an item",
  }
  for k, v in pairs(over or {}) do
    t[k] = v
  end
  return check.must(item.decode(t))
end

-- Two open items sharing a key: `_work.lanes.mint`'s own idempotency
-- key is only checked at mint time, so a hand-edited second claimant
-- is exactly the shape `fsck` exists to catch.
local function test_two_open_items_in_one_key_is_a_problem()
  local a = make_item({key = "release.yml"})
  local b = make_item({id = check.must(ksuid.encode(1690000003, ("\4"):rep(16))),
      key = "release.yml"})
  local problems = fsck.structural_problems({a, b})
  local found = false
  for _, p in ipairs(problems) do
    if p:find("release.yml", 1, true) ~= nil then
      found = true
    end
  end
  assert(found, table.concat(problems, "; "))
end

-- A root carrying a `repo` never survives `item.problems`'s own gate
-- at write time — `structural_problems` re-asks it anyway, over a
-- hand-built record no write path produced, the same defense in depth
-- every other check here is.
local function test_a_root_with_a_repo_is_a_problem()
  local root = make_item({repo = "cosmic-lua/cosmic"})
  local problems = fsck.structural_problems({root})
  local found = false
  for _, p in ipairs(problems) do
    if p:find("a root takes no repo", 1, true) ~= nil then
      found = true
    end
  end
  assert(found, table.concat(problems, "; "))
end

-- `decode_problems` a tolerant decode already flagged rides straight
-- through as an `fsck` problem too — the read that shows everything
-- else about the board shows this.
local function test_a_flagged_item_is_a_problem()
  local flagged = make_item()
  flagged.decode_problems = {"a made-up content problem"}
  local problems = fsck.structural_problems({flagged})
  assert(#problems == 1 and problems[1]:find("a made-up content problem", 1, true) ~= nil,
    table.concat(problems, "; "))
end

-- The residue of a half-landed resolution from before this rule: the
-- pushing credential landed the create half of an old-style
-- items -> ended move and lost the delete half, leaving one id filed
-- under BOTH namespaces at once. `list` must keep exactly one entry
-- for it — the descendant commit, here the one hand-filed under
-- refs/heads/ended — so every other reader built on `list` sees one
-- item, never two, and `fsck` names the leftover for a human with
-- delete rights to clear.
local function test_a_duplicated_id_dedupes_and_fsck_names_it()
  local s = fixture.init_state_repo("fsck-duplicate")
  local id = fixture.file_item(s, "an item filed twice", "")
  local items_sha = (check.must(child.run(
        {"git", "rev-parse", "refs/heads/items/" .. id}, {cwd = s.root})).stdout
    :gsub("%s+$", ""))

  -- Resolve it — under the fix this is an ordinary save that STAYS on
  -- refs/heads/items — then hand-file the resulting commit under
  -- refs/heads/ended too, and roll refs/heads/items back to the
  -- pre-resolution sha: exactly the shape a lost delete leaves, with
  -- ended/ holding the newer, descendant commit.
  local it = check.must(store.load(s, id))
  it.resolution = "completed"
  assert(store.save(s, it, "done " .. id:sub(1, 8)))
  local done_sha = (check.must(child.run(
        {"git", "rev-parse", "refs/heads/items/" .. id}, {cwd = s.root})).stdout
    :gsub("%s+$", ""))
  fixture.git(s.root, {"update-ref", "refs/heads/ended/" .. id, done_sha})
  fixture.git(s.root, {"update-ref", "refs/heads/items/" .. id, items_sha})

  local all = check.must(store.list(s))
  local matches = 0
  local seen: item.Item = nil
  for _, x in ipairs(all) do
    if x.id == id then
      matches = matches + 1
      seen = x
    end
  end
  assert(matches == 1, ("exactly one Item for the duplicated id: got %d"):format(matches))
  assert(seen.resolution == "completed",
    "the kept entry is the descendant — the done commit's state")

  -- `show`/`resolve` of its handle is unambiguous.
  assert(gitboard.main("show", tail.handle(id), "--dir", s.root) == 0,
    "show resolves the duplicated handle without ambiguity")

  -- `find`'s index builds — the UNIQUE constraint this bug used to
  -- trip lived in `_work.index`'s `items` table, one row per id.
  assert(check.must(index.open(all)), "the index builds with one row per id")

  -- `fsck` names the duplicate and the exact command to clear it.
  local code, printed = fsck_and_capture(s)
  assert(code ~= 0, "a duplicated id is an fsck problem: " .. printed)
  assert(printed:find("filed under both", 1, true) ~= nil, printed)
  assert(printed:find("refs/heads/items/" .. id, 1, true) ~= nil, printed)
  assert(printed:find("refs/heads/ended/" .. id, 1, true) ~= nil, printed)
  assert(printed:find("git push origin --delete refs/heads/items/" .. id, 1, true) ~= nil,
    printed)
end

--- `fsck`'s `tree_problem` used to spend one `git rev-parse` PER item
--- reading its observed tree, plus a `hash-object`/`mktree` process
--- chain per item re-encoding it. Both are gone: the tree lookup is
--- one batched `git rev-parse` for the whole board
--- (`gitobj.tree_of_batch`), and the re-encode is a pure Lua hash with
--- no process at all — so the whole audit's process count must stay
--- flat as the board grows. Counted by racing `git` itself: a
--- counting wrapper ahead of the real binary on PATH, so every
--- invocation `_work.gitobj`/`_work.refs`/`_work.store` make is
--- caught, not just the ones this test happens to know the argv for.
---
--- The wrapper is installed by editing THIS process's own `PATH`
--- (`env.set`), never by spawning `gitboard` as a fresh subprocess:
--- `cosmic.child`'s PATH lookup (`unix.commandv`, underneath every
--- spawn) resolves `"git"` against the CALLING process's own
--- environment, so an in-process `fsck.cmd_fsck(s)` call already runs
--- every nested `git` invocation through whatever this process's PATH
--- says at that moment.
local function test_fsck_process_count_is_constant_as_items_grow()
  local real_git = check.must(child.run({"sh", "-c", "command -v git"})).stdout
  real_git = (real_git:gsub("%s+$", ""))
  local wrapdir = fs.join(tmpdir, "fsck-git-wrap")
  assert(fs.remove_all(wrapdir))
  assert(fs.make_dirs(wrapdir))
  local counter_file = fs.join(tmpdir, "fsck-git-count.txt")
  assert(fs.write(counter_file, ""))
  assert(fs.write(fs.join(wrapdir, "git"),
      ("#!/bin/sh\nprintf x >> '%s'\nexec '%s' \"$@\"\n"):format(counter_file, real_git)))
  assert(fs.set_mode(fs.join(wrapdir, "git"), fs.octal("755")))

  --- A fresh board with `n` plain workable items, each its own root —
  --- enough for `fsck` to have real trees and specs to re-check.
  --- @param name string This board's own scratch directory
  --- @param n integer How many items to file
  --- @return store.Store The store
  local function seed(name: string, n: integer): store.Store
    local s = init_state_repo(name)
    for i = 1, n do
      fixture.file_item(s, ("item %d"):format(i), "")
    end
    return s
  end

  --- How many `git` invocations one `fsck.cmd_fsck` makes, with the
  --- wrapper ahead of the real binary on PATH for this call alone.
  --- @param s store.Store The store to audit
  --- @return integer Invocation count
  local function fsck_process_count(s: store.Store): integer
    assert(fs.write(counter_file, ""))
    local old_path = os.getenv("PATH") or ""
    assert(env.set("PATH", wrapdir .. ":" .. old_path, true))
    fsck.cmd_fsck(s)
    assert(env.set("PATH", old_path, true))
    return #(fs.read(counter_file) or "")
  end

  local small = fsck_process_count(seed("fsck-procs-small", 3))
  local big = fsck_process_count(seed("fsck-procs-big", 12))
  assert(small > 0, "the wrapper caught at least one invocation")
  assert(small == big,
    ("fsck's process count must not grow with item count: %d (3 items) vs "
      .. "%d (12 items)"):format(small, big))
end
