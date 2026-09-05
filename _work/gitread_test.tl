#!/usr/bin/env cosmic
-- `_work.gitread`'s single-item fast path: `load` given a
-- caller-resolved ref and sha skips its own for-each-ref entirely, no
-- matter which caller resolved them — `_work.store.resolve`'s own
-- snapshot on an unambiguous prefix match, or `_work.gitboard`'s tail
-- (handle) branch handing it a `list` snapshot's lease, both of which
-- are exercised end to end in `_work/gitboard_test.tl`. With neither
-- ref nor sha given, `load` falls back to its usual single for-each-ref.

local check = require("cosmic.check")
local fixture = require("_work.fixture")
local gitread = require("_work.gitread")
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
