#!/usr/bin/env cosmic
-- The dispatcher's id resolution: every id-taking argument position —
-- not only the first — accepts a rendered handle, and a handle that
-- names nothing is refused the same way a bad prefix is. The verbs
-- themselves are exercised with resolved ids elsewhere
-- (`_work/gitcompare_test.tl`, `_work/gitgraph_test.tl`); this is the
-- dispatch layer in `_work/gitboard.tl` that resolves what a session
-- typed before a verb ever sees it.

local cache = require("_work.cache")
local cachedb = require("_work.cachedb")
local check = require("cosmic.check")
local cmp = require("_work.gitcompare")
local fixture = require("_work.fixture")
local fs = require("cosmic.fs")
local gitboard = require("_work.gitboard")
local item = require("_work.item")
local refs = require("_work.refs")
local store = require("_work.store")
local tail = require("_work.tail")

local init_state_repo = fixture.init_state_repo
local file_item = fixture.file_item
local tmpdir = fixture.tmpdir
local READY_SPEC = fixture.READY_SPEC

--- Run gitboard.main(...) and capture exactly what it prints via
--- print() -- the same swap-and-restore pattern _eval/score_test.tl
--- uses to pin a CLI's exact console output, without a real subprocess.
--- @param ... string Arguments to pass to gitboard.main, as on argv
--- @return integer gitboard.main's exit code
--- @return string Every print()'d line, newline-joined, no trailing newline
local function gitboard_and_capture(...: string): integer, string
  local old_print = _G.print
  local lines: {string} = {}
  _G.print = function(...: any)
    local parts: {string} = {}
    for i = 1, select("#", ...) do
      parts[i] = tostring((select(i, ...)))
    end
    lines[#lines + 1] = table.concat(parts, "\t")
  end
  local ok, result = pcall(gitboard.main, ...)
  _G.print = old_print
  if not ok then
    error(result, 0)
  end
  return result, table.concat(lines, "\n")
end

-- `attach`'s PARENT slot: a handle-form second argument resolves the
-- same as a prefix would, so a session pasting a handle from `show`
-- output can attach with it directly.
local function test_attach_resolves_a_handle_form_parent()
  local s = init_state_repo("attach-handle")
  local root = file_item(s, "an outcome", "")
  local leaf = file_item(s, "a workable slice", "")
  assert(gitboard.main("attach", leaf, tail.handle(root), "--dir", s.root) == 0,
    "a handle-form parent should resolve")
  local it = check.must(store.load(s, leaf))
  assert(it.parent == root, "and the attach actually landed")
end

-- `compare`'s OTHER slot: same handle form, same resolution.
local function test_compare_resolves_a_handle_form_other()
  local s = init_state_repo("compare-handle")
  local low = file_item(s, "the lesser outcome", "")
  local high = file_item(s, "the greater outcome", "")
  assert(gitboard.main("compare", high, tail.handle(low), "--dir", s.root) == 0,
    "a handle-form OTHER should resolve")
  local winner = check.must(store.load(s, high))
  assert(#winner.beats == 1 and winner.beats[1] == low,
    "and the comparison actually landed")
end

-- A handle naming nothing is refused cleanly in a secondary slot too
-- — no crash, just the same "no item matches" store gives arg 1.
local function test_secondary_slot_refuses_a_handle_that_matches_nothing()
  local s = init_state_repo("compare-handle-miss")
  local low = file_item(s, "the lesser outcome", "")
  local high = file_item(s, "the greater outcome", "")
  assert(gitboard.main("compare", high, "«ZZZZ_ZZZZ»", "--dir", s.root) ~= 0,
    "a handle matching nothing is refused")
  local winner = check.must(store.load(s, high))
  assert(#winner.beats == 0, "and nothing was recorded")
  local loser = check.must(store.load(s, low))
  assert(#loser.beats == 0, "the unrelated item is untouched")
  assert(cmp.cmd_compare(s, high, low) == 0,
    "the store is still writable after the refusal")
end

-- `gitboard help` names the two id forms a session actually meets:
-- the handle every render leads with, and the branch prefix that is a
-- DIFFERENT string from it -- the confusion this item exists to close.
local function test_help_documents_the_id_forms()
  local code, printed = gitboard_and_capture("help")
  assert(code == 0, "help should exit 0, got " .. code)
  assert(printed:find("KSUIDs", 1, true),
    "help should say ids are KSUIDs\ngot: " .. printed)
  assert(printed:find("last 8", 1, true),
    "help should name the handle as the id's last 8 characters\ngot: " .. printed)
  assert(printed:find("«d0x1_37YJ»", 1, true),
    "help should carry the worked handle example\ngot: " .. printed)
  assert(printed:find("bare or wrapped", 1, true),
    "help should say a handle is accepted bare or wrapped\ngot: " .. printed)
  assert(printed:find("unambiguous prefix", 1, true),
    "help should say an unambiguous prefix also works\ngot: " .. printed)
  assert(printed:find("branches are named", 1, true),
    "help should describe how branches are named\ngot: " .. printed)
  assert(printed:find("first 8", 1, true),
    "help should name the branch as the id's first 8 characters\ngot: " .. printed)
  assert(printed:find("different string", 1, true),
    "help should call out that the branch differs from the handle\ngot: " .. printed)
end

-- `resolve_id`'s tail (handle) branch leases the id it resolves to
-- from its own `for-each-ref` glob's matched row, the same one-shot
-- ticket a prefix match leaves for `load` — so `show <handle>` never
-- repeats a for-each-ref for the id it already found.
local function test_show_with_a_handle_never_repeats_loads_for_each_ref()
  local s = init_state_repo("show-handle-lease")
  local id = file_item(s, "an item", "")
  -- `new`'s own pre-mint duplicate check already warms `o/board.db` as
  -- a side effect (`_work.cachequery.similar_lines`); wipe it so this
  -- resolves through the glob this test is actually about, not the
  -- cache-first path — which cannot carry a lease at all (no ref/sha
  -- column exists to carry it) and is covered on its own terms by
  -- `test_a_handle_absent_from_the_cache_resolves_through_the_glob`.
  cachedb.wipe(s.root)
  local exact_pattern = {"refs/heads/items/" .. id, "refs/heads/ended/" .. id}

  local exact_calls = 0
  local real_for_each_ref = refs.for_each_ref
  refs.for_each_ref = function(root: string, patterns: {string}):
    {refs.RefEntry} | nil, string
    if #patterns == 2 and patterns[1] == exact_pattern[1]
    and patterns[2] == exact_pattern[2] then
      exact_calls = exact_calls + 1
    end
    return real_for_each_ref(root, patterns)
  end
  local ok, code = pcall(gitboard_and_capture, "show", tail.handle(id), "--dir", s.root)
  refs.for_each_ref = real_for_each_ref
  if not ok then
    error(code, 0)
  end
  assert(code == 0, "show <handle> should succeed")
  assert(exact_calls == 0, "a handle's own load must not repeat the "
    .. "exact-ref for-each-ref a bare id's load would run: " .. exact_calls)
end

-- Resolving a handle must never fall back to a whole-board load:
-- `spec` is a verb whose own body never calls `store.list` either, so
-- a stub that fails the test on any call proves resolution itself
-- reaches for it no more than the verb it feeds does (zero times).
local function test_handle_resolution_never_loads_the_whole_board()
  local s = init_state_repo("handle-no-list")
  local id = file_item(s, "an item", "")
  local spec_path = fs.join(tmpdir, "handle-no-list-spec.md")
  assert(fs.write(spec_path, READY_SPEC))
  local real_list = store.list
  store.list = function(_s: store.Store): {item.Item} | nil, string
    error("store.list must not run to resolve a handle", 0)
  end
  local ok, code = pcall(gitboard.main, "spec", tail.handle(id), spec_path, "--dir", s.root)
  store.list = real_list
  if not ok then
    error(code, 0)
  end
  assert(code == 0, "spec ID FILE should resolve a handle without a whole-board load")
end

-- A handle's case does not have to match what `for-each-ref`'s own
-- fnmatch would require exactly — retyping tolerance costs one MORE
-- for-each-ref (the whole-namespace, names-only fallback), never a
-- whole-board load.
local function test_a_mixed_case_handle_resolves_through_the_fallback()
  local s = init_state_repo("handle-case-fold")
  local id = file_item(s, "an item", "")
  -- The cache's own lookup already folds case (`lower(id) LIKE
  -- '%'||lower(?)`), so it would answer this one directly; wipe the
  -- cache `new`'s pre-mint check warmed so this exercises the GLOB's
  -- own case-fold fallback instead.
  cachedb.wipe(s.root)
  local flipped = tail.bare(id):gsub("%a", function(c: string): string
      if c:match("%u") then
        return c:lower()
      end
      return c:upper()
    end)
  local fallback_pattern = {"refs/heads/items/*", "refs/heads/ended/*"}
  local fallback_calls = 0
  local real_for_each_ref = refs.for_each_ref
  refs.for_each_ref = function(root: string, patterns: {string}):
    {refs.RefEntry} | nil, string
    if #patterns == 2 and patterns[1] == fallback_pattern[1]
    and patterns[2] == fallback_pattern[2] then
      fallback_calls = fallback_calls + 1
    end
    return real_for_each_ref(root, patterns)
  end
  local ok, code = pcall(gitboard.main, "show", "«" .. flipped .. "»", "--dir", s.root)
  refs.for_each_ref = real_for_each_ref
  if not ok then
    error(code, 0)
  end
  assert(code == 0, "a mixed-case handle should resolve through the fallback")
  assert(fallback_calls == 1,
    "expected exactly one fallback for-each-ref call, got " .. fallback_calls)
end

-- The cache only helps when it already carries the id: an item newer
-- than the file — a fetch this checkout has not caught up to, say —
-- still resolves, by falling through to the glob.
local function test_a_handle_absent_from_the_cache_resolves_through_the_glob()
  local s = init_state_repo("handle-cache-miss")
  check.must(cache.close(check.must(cache.open(s.root)))) -- primes o/board.db
  local id = file_item(s, "an item filed after the cache existed", "")
  local db = check.must(cachedb.open_conn(cachedb.path_of(s.root)))
  -- `events.item` REFERENCES `items(id)`; the filing above already gave
  -- this id one row there, so it goes first or the plain `items` delete
  -- below trips that foreign key.
  assert(db:exec("DELETE FROM events WHERE item = ?", {id}))
  assert(db:exec("DELETE FROM items WHERE id = ?", {id}))
  check.must(db:close())
  assert(gitboard.main("show", tail.handle(id), "--dir", s.root) == 0,
    "a handle absent from the cache should still resolve through the glob")
end
