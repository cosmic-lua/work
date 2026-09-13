#!/usr/bin/env cosmic
-- The write path's own process-count properties: a mutation snapshots
-- and loads the board exactly once before it writes, re-reads only
-- the refs its own fast-import touched, never asks git about a spec
-- sidecar for an id that does not exist yet, and reads the ad hoc
-- `git remote`/`git remote get-url origin` facts at most once per
-- store. Its own file, alongside `_work/gitgraph.tl` (`new`) and
-- `_work/gitrank.tl` (`rank`), rather than folded into either verb's
-- own `_test.tl` — `gitgraph_test.tl` is at the line cap already, and
-- this property belongs to the write path shared by every mutation
-- verb, not to one verb's own test file.

local cache = require("_work.cache")
local check = require("cosmic.check")
local child = require("cosmic.child")
local env = require("cosmic.env")
local fixture = require("_work.fixture")
local fs = require("cosmic.fs")
local gh = require("_work.gh")
local gitread = require("_work.gitread")
local gitreadspec = require("_work.gitreadspec")
local itemtree = require("_work.itemtree")
local graph = require("_work.gitgraph")
local rank = require("_work.gitrank")
local publish = require("_work.publish")
local refs = require("_work.refs")
local store = require("_work.store")

local tmpdir = os.getenv("TEST_TMPDIR") or "/tmp"

local SPEC_BODY < const >: itemtree.Spec = {change = "do it\n", non_goals = "not that\n"}

--- A mutable call counter for a swapped-out module function, carrying
--- its own restore alongside it (rather than a second return value) so
--- no signature here ever returns a bare `function()`, which the
--- formatter mis-indents when the line wraps.
local record Counter
  n: integer
  calls: {string}
  restore: function()
end

--- Swap `refs.for_each_ref` for a counting wrapper that still runs the
--- real thing, so every module sharing the `refs` table (`_work.store`,
--- `_work.cachedb`, `_work.gitread`, `_work.gitwrite`, `_work.publish`,
--- ...) is caught, not just a direct call this test happens to know
--- the argv for.
--- @return Counter The live counter; call `.restore()` exactly once
local function count_for_each_ref(): Counter
  local original = refs.for_each_ref
  local counter: Counter = {n = 0, calls = {}, restore = function()
      refs.for_each_ref = original
    end}
  refs.for_each_ref = function(root: string, patterns: {string}):
    {refs.RefEntry} | nil, string
    counter.n = counter.n + 1
    counter.calls[#counter.calls + 1] = table.concat(patterns, ",")
    return original(root, patterns)
  end
  return counter
end

--- The same wrapper for `gitread.load` — the single-item read path a
--- mutation verb never takes (they all read through `store.list`), so
--- a non-zero count here would mean a verb fell back to per-item reads.
--- @return Counter The live counter; call `.restore()` exactly once
local function count_gitread_load(): Counter
  local original = gitread.load
  local counter: Counter = {n = 0, restore = function()
      gitread.load = original
    end}
  gitread.load = function(root: string, id: string, known_ref?: string,
      known_sha?: string): gitread.Loaded | nil, string
    counter.n = counter.n + 1
    return original(root, id, known_ref, known_sha)
  end
  return counter
end

-- `new` on a remote-mode fixture takes one canonical `for-each-ref`
-- snapshot (`store.list`, inside `cmd_new`). The successor is prepared,
-- not confirmed, so it neither patches the canonical cache nor takes a
-- second canonical snapshot. The cache is warmed
-- first so `similar_lines`'s own `cache.open` finds a file already
-- valid at the snapshot `store.list` just took, the same way a real
-- run's second-and-later mutation always does.
local function test_new_reads_the_board_once_and_rereads_only_the_written_ref()
  local a, _b = fixture.init_shared("new-load-count")
  local warm = check.must(cache.rebuild(a.root))
  assert(cache.close(warm))

  local fe = count_for_each_ref()
  local ld = count_gitread_load()
  local rc = graph.cmd_new(a, "counted new item", "", SPEC_BODY, "")
  fe.restore()
  ld.restore()

  assert(rc == 0, "new should be accepted")
  assert(ld.n == 0, "new must never fall back to a per-item load: got " .. ld.n)
  assert(fe.n == 2, ("new should pay one board snapshot plus the duplicate "
      .. "search's guarded cache open, and must not patch an unconfirmed "
      .. "successor into the cache: got %d")
    :format(fe.n))
end

-- `rank` on the same kind of fixture: the defect this item's Evidence
-- names directly — a second, full `store.list` call after the write,
-- to report the new standing, which loaded the whole board's
-- cat-file batches a second time. The other ref enumeration is the
-- deliberately narrow format-marker compatibility check before a
-- write. Ranking a CHILD under its parent
-- exercises the same `commit_and_publish` path `new` above does —
-- an outcome's own `rank` (the board's own `order`) goes through the
-- identical path too, since the board is simply its parent.
local function test_rank_reads_the_board_once_not_twice()
  local a, _b = fixture.init_shared("rank-load-count")
  assert(graph.cmd_new(a, "an outcome", "", nil, "") == 0)
  fixture.caller_publish(a)
  local seeded = check.must(store.list(a))
  assert(#seeded == 2, "the board plus one outcome should be on the board: got "
    .. #seeded)
  local root: string = nil
  for _, i in ipairs(seeded) do
    if (i.parent or "") ~= "" then
      root = i.id
    end
  end
  assert(root ~= nil, "the new outcome is on the board")
  local before_ids: {string: boolean} = {}
  for _, i in ipairs(seeded) do
    before_ids[i.id] = true
  end
  -- Filed under the board, then attached under root with no --before/
  -- --after — unlike `new --parent root` directly, which would rank a
  -- bare child last on its own — so `kid` starts genuinely unranked
  -- and the `rank` call below pays its real write path instead of
  -- finding nothing left to do.
  assert(graph.cmd_new(a, "a piece of it", "", nil, "") == 0)
  fixture.caller_publish(a)
  local triaged = check.must(store.list(a))
  local unplaced: string = nil
  for _, i in ipairs(triaged) do
    if not before_ids[i.id] then
      unplaced = i.id
    end
  end
  assert(unplaced ~= nil, "the new piece should be on the board")
  assert(graph.cmd_attach(a, unplaced, root) == 0, "attach should be accepted")
  fixture.caller_publish(a)
  local direct = check.must(store.load(a, unplaced))
  assert(direct.parent == root,
    "the caller-confirmed item ref carries its new parent: " .. direct.parent)
  assert(a.index == nil, "the mutation closed the pre-transport cache handle")
  local kid = unplaced

  -- The two seeding reads above already opened `a`'s own board cache
  -- (`store.list` holds it for the rest of this invocation) — closed
  -- here so `cmd_rank` below pays its own fresh snapshot, exactly as a
  -- real `rank` invocation would starting from nothing, rather than
  -- reusing a connection this test's own setup happened to warm.
  local _cok, _cerr = store.close(a)

  local warm = check.must(cache.rebuild(a.root))
  assert(cache.close(warm))

  local fe = count_for_each_ref()
  local ld = count_gitread_load()
  local rc = rank.cmd_rank(a, kid, "", "", true)
  fe.restore()
  ld.restore()

  assert(rc == 0, "rank should be accepted")
  assert(ld.n == 0, "rank must never fall back to a per-item load: got " .. ld.n)
  assert(fe.n == 2, ("rank should take one board snapshot and one narrow "
      .. "format-marker read: got %d (%s)")
    :format(fe.n, table.concat(fe.calls, "; ")))
  assert(fe.calls[1] == table.concat({"refs/heads/items", "refs/heads/ended",
        "refs/heads/board"}, ","), "first read must be the canonical board snapshot")
  assert(fe.calls[2] == "refs/heads/items,refs/heads/ended,refs/heads/board/format",
    "second read must be the narrow write compatibility check")
end

-- `new` never asks git for the minted id's prose: the id being minted
-- has no ref yet, so any candidate read is guaranteed to come back
-- empty. `gitreadspec.read_spec` is the one function that
-- makes that ask; stubbing it to fail outright proves `new` never
-- calls it at all for a brand-new item, not merely that its failure is
-- tolerated.
local function test_new_never_reads_spec_md_for_the_minted_id()
  local a = fixture.init_state_repo("new-no-spec-read")
  local original = gitreadspec.read_spec
  gitreadspec.read_spec = function(_root: string,
      _candidates: {string}): itemtree.Spec
    error("gitreadspec.read_spec must never be asked about an id new is "
      .. "still minting")
  end
  local ok, result = pcall(function(): integer
      return graph.cmd_new(a, "no spec read", "", SPEC_BODY, "")
    end)
  gitreadspec.read_spec = original
  assert(ok, "new must not read the prose of the id it is minting: "
    .. tostring(result))
  assert(result == 0, "new should still be accepted")
end

--- A `git` on PATH, plus the restore that undoes it — bundled the same
--- way `Counter` is, so this signature never returns a bare `function()`
--- either.
local record ArgvLog
  path: string
  restore: function()
end

--- Install a `git` on PATH ahead of the real binary that appends every
--- invocation's arguments (space-joined, one line each) to a log file
--- before delegating — precise enough to tell `remote` from `remote
--- get-url origin` apart, unlike a plain invocation counter.
--- @param name string A name unique to this test, for its own scratch files
--- @return ArgvLog The log path; call `.restore()` exactly once
local function install_argv_logger(name: string): ArgvLog
  local real_git = (check.must(child.run({"sh", "-c", "command -v git"})).stdout
    :gsub("%s+$", ""))
  local wrapdir = fs.join(tmpdir, "writepath-wrap-" .. name)
  assert(fs.remove_all(wrapdir))
  assert(fs.make_dirs(wrapdir))
  local logfile = fs.join(tmpdir, "writepath-log-" .. name .. ".txt")
  assert(fs.write(logfile, ""))
  assert(fs.write(fs.join(wrapdir, "git"),
      ("#!/bin/sh\nprintf '%%s\\n' \"$*\" >> '%s'\nexec '%s' \"$@\"\n")
      :format(logfile, real_git)))
  assert(fs.set_mode(fs.join(wrapdir, "git"), fs.octal("755")))
  local old_path = os.getenv("PATH") or ""
  assert(env.set("PATH", wrapdir .. ":" .. old_path, true))
  return {path = logfile, restore = function()
      assert(env.set("PATH", old_path, true))
    end}
end

--- How many logged lines END with `suffix` on a word boundary — every
--- store-side call rides in behind `-c user.email=... -c user.name=...
--- -c core.createObject=rename`, so the git SUBCOMMAND itself is the
--- tail of the line, never the whole of it.
--- @param logfile string The path `install_argv_logger` wrote
--- @param suffix string The subcommand's own words, space-joined
--- @return integer How many logged lines end with exactly that
local function count_lines(logfile: string, suffix: string): integer
  local n = 0
  for l in (fs.read(logfile) or ""):gmatch("([^\n]*)\n?") do
    if l == suffix or l:sub(-(#suffix + 1)) == (" " .. suffix) then
      n = n + 1
    end
  end
  return n
end

-- `has_origin` and `gh.slug` each read one ad hoc git fact that never
-- changes within a run (`git remote`, `git remote get-url origin`) —
-- memoized on the store so three asks of either cost one process, not
-- three. `cmd_done` is the verb that already asks `has_origin` twice
-- in its own body before `commit_and_publish` asks a third time
-- (`_work.gitverbs.cmd_done`'s own accepted-PR check, then
-- `_work.publish.publish`'s), which is exactly the redundancy this
-- guards against.
local function test_remote_facts_are_memoized_on_the_store()
  local a, _b = fixture.init_shared("remote-memo")
  local log = install_argv_logger("remote-memo")

  assert(publish.has_origin(a), "the shared clone has an origin")
  assert(publish.has_origin(a))
  assert(publish.has_origin(a))
  -- The bare local remote is not a GitHub URL, so `slug` fails every
  -- time on the SAME grounds — the point here is the read underneath
  -- it, not the outcome, so all three calls are made and none checked.
  local _s1, _e1 = gh.slug(a, nil)
  local _s2, _e2 = gh.slug(a, nil)
  local _s3, _e3 = gh.slug(a, nil)
  log.restore()

  assert(count_lines(log.path, "remote") == 1,
    "has_origin must read `git remote` once per store, memoized")
  assert(count_lines(log.path, "remote get-url origin") == 1,
    "gh.slug must read `git remote get-url origin` once per store, memoized")
end
