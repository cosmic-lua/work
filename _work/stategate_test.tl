#!/usr/bin/env cosmic
local boardtree = require("_work.boardtree")
local check = require("cosmic.check")
local child = require("cosmic.child")
local env = require("cosmic.env")
local fs = require("cosmic.fs")
local gitobj = require("_work.gitobj")
local item = require("_work.item")
local ksuid = require("_work.ksuid")
local stategate = require("_work.stategate")
local tx = require("_work.statetransaction")

local tmpdir = os.getenv("TEST_TMPDIR") or "/tmp"
local config = fs.join(tmpdir, "stategate-gitconfig-empty")
assert(fs.write(config, "") and env.set("GIT_CONFIG_GLOBAL", config)
  and env.set("GIT_CONFIG_NOSYSTEM", "1"))

local function bounded(gate: string): tx.Transition
  return {base = ("a"):rep(40), dependencies = {{path = "format", id = ("b"):rep(40)}},
    changes = {{path = "format", mode = "100644", content = "6\n", delete = false}},
    message = "test", author = {name = "test", email = "test@example", date = "1700000001 +0000"},
    publish_by = 0, bounded = true, gate = gate}
end

local function full_board(): string, string
  local root = fs.join(tmpdir, "stategate-board")
  assert(fs.remove_all(root) and fs.make_dirs(root))
  local init = check.must(child.run({"git", "init", "-q", root})); assert(init.ok, init.stderr)
  local item_entries: {gitobj.TreeEntry} = {}; local claim_entries: {gitobj.TreeEntry} = {}
  for n = 1, 10 do
    local id = check.must(ksuid.encode(1700000000 + n, string.char(n):rep(16)))
    local it = check.must(item.decode({id = id, title = "doing " .. n}))
    local tree = check.must(boardtree.build_item(root, it, nil, nil, true))
    item_entries[#item_entries + 1] = {mode = "40000", otype = "tree", sha = tree, name = id}
    local raw = check.must(boardtree.encode_claim({id = ("%02x"):format(n):rep(20), holder = "s" .. n,
          acquired_at = 1700000000, renewed_at = 1700000000, expires_at = 2000000000,
          product_base = ("c"):rep(40)}))
    claim_entries[#claim_entries + 1] = {mode = "100644", otype = "blob",
      sha = check.must(gitobj.hash_object_write(root, raw)), name = id}
  end
  local items = check.must(gitobj.mktree_write(root, item_entries))
  local claims = check.must(gitobj.mktree_write(root, claim_entries))
  local format = check.must(gitobj.hash_object_write(root, "6\n"))
  local tree = check.must(gitobj.mktree_write(root, {
        {mode = "100644", otype = "blob", sha = format, name = "format"},
        {mode = "40000", otype = "tree", sha = items, name = "items"},
        {mode = "40000", otype = "tree", sha = claims, name = "claims"}}))
  local head = check.must(gitobj.commit_tree(root, {tree = tree, parents = {}, message = "seed",
        author_name = "test", author_email = "test@example", author_date = "1700000001 +0000",
        committer_name = "test", committer_email = "test@example", committer_date = "1700000001 +0000", op = "seed"}))
  return root, head
end

local root, head = full_board()
local ok, err = stategate.check(root, head, bounded("doing-bound"))
assert(not ok and err == "doing bound reached", err)
local unknown, uerr = stategate.check(root, head, bounded("future-gate"))
assert(not unknown and uerr == "unknown bounded gate: future-gate")
