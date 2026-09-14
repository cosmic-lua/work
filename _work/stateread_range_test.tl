#!/usr/bin/env cosmic
local boardhistory = require("_work.boardhistory")
local boardread = require("_work.boardread")
local boardtree = require("_work.boardtree")
local cache = require("_work.cache")
local cachedb = require("_work.cachedb")
local check = require("cosmic.check")
local fixture = require("_work.fixture")
local fs = require("cosmic.fs")
local git = require("_work.singlehead_git")
local item = require("_work.item")
local ksuid = require("_work.ksuid")
local literal = require("_work.singlehead_literal")
local projection = require("_work.stateplan_git")
local refs = require("_work.refs")
local stateinit = require("_work.stateinit")
local statecache = require("_work.stateread_cache")
local tx = require("_work.statetransaction")

local function commit(root: string, base: string, changes: {tx.Change}): string
  local tree = check.must(projection.apply(root, base, changes))
  return check.must(git.text(root, {"commit-tree", tree, "-p", base}, "log by range-test head: fixture\n", {
        GIT_AUTHOR_NAME = "range-test", GIT_AUTHOR_EMAIL = "test@example.invalid",
        GIT_COMMITTER_NAME = "range-test", GIT_COMMITTER_EMAIL = "test@example.invalid"}))
end

local function note(root: string, base: string, id: string, body: string): string
  return commit(root, base, {{path = "items/" .. id .. "/log/" .. ksuid.new() .. ".md",
        mode = "100644", content = body, delete = false}})
end

local function rows(root: string): string
  local db = check.must(cachedb.open_conn(cachedb.path_of(root)))
  local out: {string: {{string: any}}} = {}
  for _, query in ipairs({"SELECT id,tip,touched_at,title,claim FROM items ORDER BY id",
      "SELECT * FROM events ORDER BY item,seq", "SELECT * FROM state_paths ORDER BY path"}) do
    local values: {{string: any}} = {}
    for row in check.must(db:query(query)) do values[#values + 1] = row end
    out[query] = values
  end
  assert(db:close())
  return check.must(literal.encode(out))
end

local function test_incremental_range_retains_old_events_and_untouched_item_tips()
  local root = fs.join(fixture.tmpdir, "native-incremental-range")
  assert(fs.remove_all(root) and stateinit.init(root))
  assert(refs.set_board_mode(root, "local"))
  local initial = check.must(git.oid(root, "refs/heads/state"))
  local board = check.must(boardread.list(root, initial)).items[1]
  local id = ksuid.new()
  local other = check.must(item.decode({id = id, parent = board.id, title = "untouched"}))
  local subtree = check.must(boardtree.build_item(root, other, nil, nil, true))
  local changes: {tx.Change} = {}
  for _, entry in ipairs(check.must(boardtree.snapshot_entries(root, subtree))) do
    changes[#changes + 1] = {path = "items/" .. id .. "/" .. entry.path, mode = entry.mode,
      content = check.must(git.run(root, {"cat-file", "blob", entry.sha})), delete = false}
  end
  local base = commit(root, initial, changes)
  base = note(root, base, board.id, "old note\n")
  assert(refs.update_ref(root, "refs/heads/state", base, initial))
  assert(cache.close(check.must(cache.open(root))))
  local before = check.must(boardhistory.read(root, base))
  local one = note(root, base, board.id, "new note one\n")
  local two = note(root, one, board.id, "new note two\n")
  local head = commit(root, two, {})
  local range = check.must(boardhistory.read(root, head, base))
  assert(#range.events == 2 and range.events[1].sha == one and range.events[2].sha == two)
  assert(range.tip_by_id[id] == nil and range.tip_by_id[board.id] == two)
  assert(refs.update_ref(root, "refs/heads/state", head, base))
  assert(statecache.patch(root, base, head))
  local patched = rows(root)
  local db = check.must(cachedb.open_conn(cachedb.path_of(root)))
  local count = check.must(db:query_one("SELECT COUNT(*) AS n FROM events"))
  assert(count.n == #before.events + 2, "range patch must append, preserving indexed events")
  local unchanged = check.must(db:query_one("SELECT tip FROM items WHERE id=?", {id}))
  assert(unchanged.tip == before.tip_by_id[id], "a disjoint item keeps its attributed tip")
  assert(cachedb.meta_get(db, "refs_digest") == head)
  assert(db:close())
  assert(cache.close(check.must(cache.rebuild(root))))
  assert(rows(root) == patched, "incremental range projection must equal a full rebuild")
  assert(statecache.patch(root, base, head))
  assert(rows(root) == patched, "a stale patch request must not duplicate events")
end

local function test_range_refuses_rewind_and_second_parent_only_bases()
  local root = fs.join(fixture.tmpdir, "native-history-range-refusal")
  assert(fs.remove_all(root) and stateinit.init(root))
  local base = check.must(git.oid(root, "refs/heads/state"))
  local id = check.must(boardread.list(root, base)).items[1].id
  local left = note(root, base, id, "left\n")
  local right = note(root, base, id, "right\n")
  local tree = check.must(git.oid(root, left .. "^{tree}"))
  local merged = check.must(git.text(root, {"commit-tree", tree, "-p", left, "-p", right}, "merge\n", {
        GIT_AUTHOR_NAME = "test", GIT_AUTHOR_EMAIL = "test@example.invalid",
        GIT_COMMITTER_NAME = "test", GIT_COMMITTER_EMAIL = "test@example.invalid"}))
  local range, err = boardhistory.read(root, merged, right)
  assert(range == nil and err == boardhistory.NOT_FAST_FORWARD)
  range, err = boardhistory.read(root, base, left)
  assert(range == nil and err == boardhistory.NOT_FAST_FORWARD)
  assert(#check.must(boardhistory.read(root, base, base)).events == 0)
end
