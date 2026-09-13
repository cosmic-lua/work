#!/usr/bin/env cosmic
local boardhistory = require("_work.boardhistory")
local boardread = require("_work.boardread")
local boardtree = require("_work.boardtree")
local check = require("cosmic.check")
local child = require("cosmic.child")
local env = require("cosmic.env")
local fs = require("cosmic.fs")
local gitobj = require("_work.gitobj")
local gitreadlog = require("_work.gitreadlog")
local item = require("_work.item")
local ksuid = require("_work.ksuid")

local tmpdir = os.getenv("TEST_TMPDIR") or "/tmp"
local config = fs.join(tmpdir, "boardtree-gitconfig-empty")
assert(fs.write(config, "") and env.set("GIT_CONFIG_GLOBAL", config)
  and env.set("GIT_CONFIG_NOSYSTEM", "1"))

local function repo(name: string): string
  local root = fs.join(tmpdir, "boardtree-" .. name)
  assert(fs.remove_all(root) and fs.make_dirs(root))
  local r = check.must(child.run({"git", "init", "-q", root})); assert(r.ok, r.stderr)
  return root
end

local function test_claim_and_marks_are_canonical_literals()
  local id = ("ab"):rep(20)
  local raw = check.must(boardtree.encode_claim({id = id, holder = "session-a",
        acquired_at = 10, renewed_at = 20, expires_at = 30, product_base = ("cd"):rep(20)}))
  local got = check.must(boardtree.decode_claim(raw))
  assert(got.id == id and got.holder == "session-a" and got.renewed_at == 20)
  assert(select(1, boardtree.decode_claim(raw .. "\n")) == nil)
  local marks = check.must(boardtree.encode_marks({[id] = ("ef"):rep(20)}))
  assert(check.must(boardtree.decode_marks(marks))[id] == ("ef"):rep(20))
end

local function test_history_logical_author()
  local encoded = check.must(require("_work.singlehead_literal").encode(
      {name = "Session", email = "session@example", date = "1700000000 +0000"}))
  assert(boardhistory.logical_author(encoded, "Provider <provider@example>")
    == "Session <session@example>")
  assert(boardhistory.logical_author("malformed", "Provider <provider@example>")
    == "Provider <provider@example>")
end

local function test_exact_snapshot_and_history()
  local root = repo("snapshot")
  local id = check.must(ksuid.encode(1700000000, ("x"):rep(16)))
  local it = check.must(item.decode({id = id, title = "native", claim_batch = ("11"):rep(20)}))
  local itree = check.must(boardtree.build_item(root, it,
      {change = "Do it.\n", non_goals = "No more.\n"}, {abc = "log body\n", marker = ""}, true))
  local items = check.must(gitobj.mktree_write(root,
      {{mode = "40000", otype = "tree", sha = itree, name = id}}))
  local claim_text = check.must(boardtree.encode_claim({id = ("22"):rep(20), holder = "s",
        acquired_at = 1700000000, renewed_at = 1700000000, expires_at = 1700000100,
        product_base = ("33"):rep(20)}))
  local claim_sha = check.must(gitobj.hash_object_write(root, claim_text))
  local claims = check.must(gitobj.mktree_write(root,
      {{mode = "100644", otype = "blob", sha = claim_sha, name = id}}))
  local format = check.must(gitobj.hash_object_write(root, "6\n"))
  local tree = check.must(gitobj.mktree_write(root, {
        {mode = "100644", otype = "blob", sha = format, name = "format"},
        {mode = "40000", otype = "tree", sha = items, name = "items"},
        {mode = "40000", otype = "tree", sha = claims, name = "claims"}}))
  local logical = check.must(require("_work.singlehead_literal").encode(
      {name = "Session", email = "session@example", date = "1700000010 +0000"}))
  logical = logical:gsub("\n$", "")
  local head = check.must(gitobj.commit_tree(root, {tree = tree, parents = {}, message = "take native by s\n\n"
        .. "Gitboard-Author: " .. logical .. "\nTransaction: test",
        author_name = "s", author_email = "s@x", author_date = "1700000010 +0000",
        committer_name = "gitboard", committer_email = "g@x", committer_date = "1700000010 +0000", op = ""}))
  local configured = check.must(child.run({"git", "-C", root, "config", "trailer.separators", "%"}))
  assert(configured.ok, configured.stderr)
  configured = check.must(child.run({"git", "-C", root, "config", "trailer.Gitboard-Author.key", "Foo"}))
  assert(configured.ok, configured.stderr)
  local view = check.must(boardread.list(root, head, 1700000050))
  assert(#view.items == 1 and view.items[1].claim == "s"
    and view.items[1].claim_batch == ("22"):rep(20))
  local expired = check.must(boardread.list(root, head, 1700000100)).items[1]
  assert(expired.claim == "" and expired.claim_base == ("33"):rep(20)
    and expired.claim_batch == ("22"):rep(20))
  assert(view.specs_by_id[id].change == "Do it.\n" and view.logs_by_id[id].abc == "log body\n")
  assert(view.logs_by_id[id].marker == nil and view.raw_logs_by_id[id].marker == "")
  local meta = check.must(gitobj.cat_file_batch(root, {head .. ":items/" .. id .. "/meta"}))
  assert(not meta[head .. ":items/" .. id .. "/meta"].content:find("claim_batch", 1, true))
  assert(check.must(boardtree.path_id(root, head, "missing")) == boardtree.ZERO_SHA)
  local history = check.must(boardhistory.read(root, head))
  assert(#history.events_by_id[id] == 1 and history.tip_by_id[id] == head
    and history.touched_by_id[id] == 1700000010)
  assert(history.events_by_id[id][1].author == "Session <session@example>")
  local item_history = check.must(gitreadlog.read_state_history(root, head, id))
  assert(#item_history == 1 and item_history[1].author == "Session <session@example>")
end

local function test_literal_sequence_indices_are_decimal()
  local literal = require("_work.singlehead_literal")
  local values: {string} = {}
  for i = 1, 10 do values[i] = "member-" .. i end
  local encoded = check.must(literal.encode(literal.sequence(values)))
  local decoded = check.must(literal.decode(encoded))
  assert(decoded is {any} and #decoded == 10 and decoded[8] == "member-8"
    and decoded[10] == "member-10")
end
