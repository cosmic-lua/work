#!/usr/bin/env cosmic
local boardtree = require("_work.boardtree")
local cachemod = require("_work.cache")
local cachedb = require("_work.cachedb")
local check = require("cosmic.check")
local child = require("cosmic.child")
local fixture = require("_work.fixture")
local format = require("_work.format")
local fs = require("cosmic.fs")
local gitobj = require("_work.gitobj")
local gitreadlog = require("_work.gitreadlog")
local item = require("_work.item")
local ksuid = require("_work.ksuid")
local refs = require("_work.refs")
local store = require("_work.store")

local function commit(root: string, tree: string, parents: {string}, message: string): string
  return check.must(gitobj.commit_tree(root, {tree = tree, parents = parents, message = message,
        author_name = "test", author_email = "test@board", committer_name = "gitboard",
        committer_email = "test@board", author_date = "1700000000 +0000",
        committer_date = "1700000000 +0000", op = "new"}))
end

local function test_native_read_and_explicit_activation()
  local root = fs.join(fixture.tmpdir, "native-read-integration")
  assert(fs.remove_all(root) and fs.make_dirs(root))
  assert(check.must(child.run({"git", "init", "-q", root})).ok)
  local id = check.must(ksuid.encode(1700000000, ("a"):rep(16)))
  local it = check.must(item.decode({id = id, title = "Native searchable item"}))
  local itree = check.must(boardtree.build_item(root, it,
      {change = "Searchable native prose", non_goals = "No extra"}, nil, true))
  local items = check.must(gitobj.mktree_write(root, {{mode = "40000", otype = "tree", sha = itree, name = id}}))
  local vblob = check.must(gitobj.hash_object_write(root, "6\n"))
  local tree = check.must(gitobj.mktree_write(root, {
        {mode = "40000", otype = "tree", sha = items, name = "items"},
        {mode = "100644", otype = "blob", sha = vblob, name = "format"}}))
  local head = commit(root, tree, {}, "new " .. id .. " Native searchable item")
  assert(refs.update_ref(root, "refs/heads/state", head, refs.ZERO_SHA))
  -- An unpublished migration state is not a board activation.
  local inactive, ierr = format.state_head(root)
  assert(inactive == nil and ierr:find("missing", 1, true))
  assert(store.open(root) == nil, "an unactivated branch grants no board read")
  local marker_tree = check.must(gitobj.mktree_write(root,
      {{mode = "100644", otype = "blob", sha = vblob, name = "format"}}))
  local marker = commit(root, marker_tree, {}, "format 6")
  assert(refs.update_ref(root, "refs/heads/board/format", marker, refs.ZERO_SHA))
  local s = check.must(store.open(root))
  assert(s.state_head == head and check.must(store.resolve(s, id:sub(1, 8))) == id)
  assert(check.must(store.load(s, id)).title == it.title)
  assert(s.leased_sha[id] == head and s.state_reads["items/" .. id] == itree)
  assert(store.read_spec(s, id).change == "Searchable native prose")
  assert(#check.must(store.list(s)) == 1)
  local cache = check.must(store.read(s))
  assert(cachedb.meta_get(cache.db, "refs_digest") == head)
  assert(cache.db:query_one("SELECT oid FROM state_paths WHERE path=?", {"items/" .. id}) ~= nil)
  local event = cache.db:query_one("SELECT sha FROM events WHERE item=?", {id})
  assert(event ~= nil and event.sha == head)
  local unrelated = commit(root, tree, {head}, "not an item event")
  assert(refs.update_ref(root, "refs/heads/state", unrelated, head))
  assert(#check.must(gitreadlog.read_state_history(root, unrelated, id)) == 1)
  assert(store.close(s))
  local next_store = check.must(store.open(root))
  assert(#check.must(store.list(next_store)) == 1 and next_store.leased_sha[id] == head)
  assert(store.close(next_store))
  it.title = "Native searchable item revised"
  local revised_item = check.must(boardtree.build_item(root, it,
      {change = "Searchable native prose", non_goals = "No extra"}, nil, true))
  local revised_items = check.must(gitobj.mktree_write(root,
      {{mode = "40000", otype = "tree", sha = revised_item, name = id}}))
  local revised_tree = check.must(gitobj.mktree_write(root, {
        {mode = "40000", otype = "tree", sha = revised_items, name = "items"},
        {mode = "100644", otype = "blob", sha = vblob, name = "format"}}))
  local revised_head = commit(root, revised_tree, {unrelated}, "set " .. id)
  assert(refs.update_ref(root, "refs/heads/state", revised_head, unrelated))
  cachemod.after_fetch(root, revised_head)
  local patched = check.must(cachedb.open_conn(cachedb.path_of(root)))
  assert(cachedb.meta_get(patched, "refs_digest") == revised_head)
  local patched_item = patched:query_one("SELECT title,tip FROM items WHERE id=?", {id})
  assert(patched_item ~= nil and patched_item.title == it.title and patched_item.tip == revised_head)
  assert(patched:close())
  local command = check.must(child.run({"o/bin/gitboard",
        "show", id, "--dir", root}, {cwd = "."}))
  assert(command.ok, command.stdout .. command.stderr)
  assert(command.stdout:find("Native searchable item", 1, true), command.stdout)
  for _, args in ipairs({{"log", id}, {"find", "searchable"}, {"fsck"}}) do
    local argv: {string} = {"o/bin/gitboard"}
    for _, option in ipairs(args) do argv[#argv + 1] = option end
    argv[#argv + 1], argv[#argv + 2] = "--dir", root
    local result = check.must(child.run(argv, {cwd = "."}))
    assert(result.ok, result.stdout .. result.stderr)
  end
  assert(#check.must(refs.for_each_ref_raw(root, {"refs/heads/items"})) == 0)
  -- Confirmed remote tracking state wins over a speculative local successor.
  assert(refs.update_ref(root, "refs/remotes/origin/board/format", marker, refs.ZERO_SHA))
  assert(refs.update_ref(root, "refs/remotes/origin/state", head, refs.ZERO_SHA))
  local legacy_blob = check.must(gitobj.hash_object_write(root, "5\n"))
  local legacy_tree = check.must(gitobj.mktree_write(root,
      {{mode = "100644", otype = "blob", sha = legacy_blob, name = "format"}}))
  local legacy_marker = commit(root, legacy_tree, {}, "local speculative marker")
  assert(refs.update_ref(root, "refs/heads/board/format", legacy_marker, marker))
  assert(refs.set_board_mode(root, "remote"))
  assert(check.must(format.state_head(root)) == head)
  local remote = check.must(store.open(root))
  assert(check.must(store.load(remote, id)).title == "Native searchable item")
  assert(remote.state_head == head and remote.leased_sha[id] == head)
  assert(store.close(remote))
  assert(refs.set_board_mode(root, "local"))
  assert(refs.update_ref(root, "refs/heads/board/format", marker, legacy_marker))
  assert(refs.update_ref(root, "refs/heads/state", refs.ZERO_SHA, revised_head))
  local missing, err = store.open(root)
  assert(missing == nil and err:find("requires refs/heads/state", 1, true))
end

local function test_unchanged_head_reprojects_claim_at_expiry_and_clock_rewind()
  local root = fs.join(fixture.tmpdir, "native-read-expiry")
  assert(fs.remove_all(root) and fs.make_dirs(root))
  assert(check.must(child.run({"git", "init", "-q", root})).ok)
  local id = check.must(ksuid.encode(1700000000, ("b"):rep(16)))
  local it = check.must(item.decode({id = id, title = "Timed native claim"}))
  local tree = check.must(boardtree.build_item(root, it, nil, nil, true))
  local items = check.must(gitobj.mktree_write(root, {{mode = "40000", otype = "tree", sha = tree, name = id}}))
  local renewed, expiry = 1700001000, 1700002000
  local claim = check.must(boardtree.encode_claim({id = ("a"):rep(40), holder = "session-a",
        acquired_at = renewed, renewed_at = renewed, expires_at = expiry, product_base = ("b"):rep(40)}))
  local claim_blob = check.must(gitobj.hash_object_write(root, claim))
  local claims = check.must(gitobj.mktree_write(root, {{mode = "100644", otype = "blob", sha = claim_blob, name = id}}))
  local marker_blob = check.must(gitobj.hash_object_write(root, "6\n"))
  local marker_tree = check.must(gitobj.mktree_write(root, {{mode = "100644", otype = "blob", sha = marker_blob, name = "format"}}))
  local marker = commit(root, marker_tree, {}, "format 6")
  local whole = check.must(gitobj.mktree_write(root, {
        {mode = "40000", otype = "tree", sha = items, name = "items"},
        {mode = "40000", otype = "tree", sha = claims, name = "claims"},
        {mode = "100644", otype = "blob", sha = marker_blob, name = "format"}}))
  local head = commit(root, whole, {}, "claim " .. id .. " by session-a")
  assert(refs.update_ref(root, "refs/heads/state", head, refs.ZERO_SHA))
  assert(refs.update_ref(root, "refs/heads/board/format", marker, refs.ZERO_SHA))
  local clock = expiry - 1
  local original_time = os.time
  os.time = function(): integer return clock end
  local ok, err = pcall(function()
      local s = check.must(store.open(root))
      assert(check.must(store.list(s))[1].claim == "session-a")
      local before = check.must(store.read(s))
      assert(cachedb.meta_get(before.db, "native_valid_until") == tostring(expiry))
      assert(before.db:exec("DELETE FROM cache_meta WHERE k IN ('native_projected_at','native_valid_until')"))
      assert(check.must(store.list(s))[1].claim == "session-a", "pre-clock native caches are rebuilt")
      local rebuilt = check.must(store.read(s))
      assert(cachedb.meta_get(rebuilt.db, "native_valid_until") == tostring(expiry))
      clock = expiry
      assert(check.must(store.list(s))[1].claim == "", "open handle expires at the exact boundary")
      assert(check.must(store.load(s, id)).claim == "", "load agrees with the projected index")
      assert(s.state_head == head and check.must(format.state_head(root)) == head)
      local expired = check.must(store.read(s))
      local row = expired.db:query_one("SELECT state FROM state WHERE id=?", {id})
      assert(row ~= nil and row.state == "todo")
      assert(store.close(s))
      local reopened = check.must(store.open(root))
      assert(check.must(store.list(reopened))[1].claim == "", "same-head persisted cache stays expired")
      clock = expiry - 1
      assert(check.must(store.list(reopened))[1].claim == "session-a", "clock rewind reprojects authority")
      clock = renewed - 301
      local future, future_err = store.list(reopened)
      assert(future == nil and future_err:find("future", 1, true) ~= nil)
      clock = renewed - 300
      assert(check.must(store.list(reopened))[1].claim == "session-a", "future refusal clears at accepted clock boundary")
      assert(store.close(reopened))
    end)
  os.time = original_time
  assert(ok, err)
end
