#!/usr/bin/env cosmic
-- `_work.gitread`'s single-item fast path: `load` given a
-- caller-resolved ref and sha skips its own for-each-ref entirely, no
-- matter which caller resolved them — `_work.store.resolve`'s own
-- snapshot on an unambiguous prefix match, or `_work.gitboard`'s tail
-- (handle) branch handing it a `list` snapshot's lease, both of which
-- are exercised end to end in `_work/gitboard_test.tl`. With neither
-- ref nor sha given, `load` falls back to its usual single for-each-ref.

local check = require("cosmic.check")
local child = require("cosmic.child")
local fixture = require("_work.fixture")
local gitread = require("_work.gitread")
local graph = require("_work.gitgraph")
local refs = require("_work.refs")
local store = require("_work.store")

local init_state_repo = fixture.init_state_repo
local file_item = fixture.file_item

--- Count `refs.for_each_ref` calls across `f`, restoring the real
--- function whether `f` succeeds or throws — the swap-and-restore
--- pattern the other verb tests use.
--- @param f function(): boolean The body to run under the counting stub
--- @return integer Calls made during `f`
local function for_each_ref_calls(f: function(): boolean): integer
  local calls = 0
  local real = refs.for_each_ref
  refs.for_each_ref = function(root: string, patterns: {string}):
    {refs.RefEntry} | nil, string
    calls = calls + 1
    return real(root, patterns)
  end
  local ok, err = pcall(f)
  refs.for_each_ref = real
  if not ok then
    error(err, 0)
  end
  return calls
end

--- Count `child.start` calls that spawn `git cat-file --batch` across
--- `f`, restoring the real function whether `f` succeeds or throws —
--- the same swap-and-restore pattern as `for_each_ref_calls` above.
--- @param f function(): boolean The body to run under the counting stub
--- @return integer Calls made during `f`
local function cat_file_spawns(f: function(): boolean): integer
  local calls = 0
  local real = child.start
  child.start = function(argv: {string}, opts?: child.Options): child.Handle | nil, string
    if argv[1] == "git" and argv[2] == "cat-file" then
      calls = calls + 1
    end
    return real(argv, opts)
  end
  local ok, err = pcall(f)
  child.start = real
  if not ok then
    error(err, 0)
  end
  return calls
end

-- `load`'s three rounds — meta/held/edges, each edge kind's own
-- subtree, and every content blob — run over ONE `cat-file --batch`
-- session (`_work.gitobj.batch_session`), not one process per round.
-- An item with a real `blocked_by` edge exercises all three rounds
-- with non-empty queries, so an unconverted round would show up here
-- as a second (or third) spawn, not merely as an idle no-op call.
local function test_load_of_an_item_with_edges_spawns_one_cat_file_process()
  local s = init_state_repo("one-spawn")
  local blocker = file_item(s, "a blocker", "")
  local id = file_item(s, "an item", "")
  assert(graph.cmd_block(s, id, blocker, false, "waiting on the blocker") == 0)

  local calls = cat_file_spawns(function(): boolean
      check.must(gitread.load(s.root, id))
      return true
    end)
  assert(calls == 1, "a load with edges must cost exactly one cat-file spawn: "
    .. calls)
end

-- `list`'s three rounds — same shape as `load`'s, across every item on
-- the board at once — likewise run over ONE `cat-file --batch`
-- session, not one process per round, regardless of how many items
-- the board holds.
local function test_list_of_a_board_with_edges_spawns_one_cat_file_process()
  local s = init_state_repo("list-one-spawn")
  local blocker = file_item(s, "a blocker", "")
  local id = file_item(s, "an item", "")
  assert(graph.cmd_block(s, id, blocker, false, "waiting on the blocker") == 0)

  local calls = cat_file_spawns(function(): boolean
      check.must(gitread.list(s.root))
      return true
    end)
  assert(calls == 1, "a list with edges must cost exactly one cat-file spawn: "
    .. calls)
end

-- `load`'s own parameter-driven fast path: given the ref and sha for
-- `id` already, it never repeats the for-each-ref that found them.
local function test_load_with_a_known_ref_and_sha_never_calls_for_each_ref()
  local s = init_state_repo("known-ref-sha")
  local id = file_item(s, "an item", "")
  local loaded = check.must(store.load(s, id))
  local ref, sha = s.leased_ref[id], s.leased_sha[id]
  assert(loaded ~= nil)

  local calls = for_each_ref_calls(function(): boolean
      check.must(gitread.load(s.root, id, ref, sha))
      return true
    end)
  assert(calls == 0, "a known ref and sha must skip load's for-each-ref: "
    .. calls)
end

-- No snapshot in hand at all (the ordinary path, e.g. the very first
-- id this process resolves): `load` falls back to its own single
-- for-each-ref, exactly as it always has.
local function test_load_with_no_snapshot_falls_back_to_one_for_each_ref()
  local s = init_state_repo("no-snapshot")
  local id = file_item(s, "another item", "")

  local calls = for_each_ref_calls(function(): boolean
      check.must(gitread.load(s.root, id))
      return true
    end)
  assert(calls == 1, "no snapshot must cost exactly one for-each-ref: "
    .. calls)
end
