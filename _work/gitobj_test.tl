#!/usr/bin/env cosmic
-- The git object plumbing `_work.store` builds on: writing blobs and
-- trees, batch-reading them back, and parsing a raw tree object's
-- bytes into entries — the one place that byte format is decoded.

local check = require("cosmic.check")
local child = require("cosmic.child")
local env = require("cosmic.env")
local fs = require("cosmic.fs")
local gitobj = require("_work.gitobj")

local tmpdir = os.getenv("TEST_TMPDIR") or "/tmp"

local hermetic_config < const > = fs.join(tmpdir, "gitconfig-empty")
assert(fs.write(hermetic_config, ""))
assert(env.set("GIT_CONFIG_GLOBAL", hermetic_config))
assert(env.set("GIT_CONFIG_NOSYSTEM", "1"))

--- A scratch git repository with nothing in it yet.
local function fresh_repo(name: string): string
  local root = fs.join(tmpdir, "gitobj-" .. name)
  assert(fs.remove_all(root))
  assert(fs.make_dirs(root))
  local r = check.must(child.run({"git", "init", "-q", root}))
  assert(r.ok, "git init failed: " .. r.stderr)
  return root
end

-- `hash_object` gives back the same sha `git hash-object` would, and
-- the object is actually written — a second read finds it.
local function test_hash_object_writes_a_real_blob()
  local root = fresh_repo("hash-object")
  local sha = check.must(gitobj.hash_object(root, "hello, board\n"))
  assert(#sha == 40 and sha:match("^[0-9a-f]+$"), "got: " .. sha)
  local r = check.must(child.run({"git", "cat-file", "-p", sha}, {cwd = root}))
  assert(r.ok and r.stdout == "hello, board\n", "the blob reads back: "
    .. tostring(r.stdout))
end

-- The empty blob is the same well-known sha every git repository
-- agrees on.
local function test_hash_object_of_empty_matches_the_well_known_sha()
  local root = fresh_repo("empty-blob")
  local sha = check.must(gitobj.hash_object(root, ""))
  assert(sha == gitobj.EMPTY_BLOB_SHA, "got: " .. sha)
end

-- `mktree` sorts its entries the way `git mktree` always has, so two
-- calls with the same entries in different orders give the same tree.
local function test_mktree_sorts_entries()
  local root = fresh_repo("mktree-sort")
  local a = check.must(gitobj.hash_object(root, "a"))
  local b = check.must(gitobj.hash_object(root, "b"))
  local t1 = check.must(gitobj.mktree(root,
      {{mode = "100644", otype = "blob", sha = a, name = "zzz"},
        {mode = "100644", otype = "blob", sha = b, name = "aaa"}}))
  local t2 = check.must(gitobj.mktree(root,
      {{mode = "100644", otype = "blob", sha = b, name = "aaa"},
        {mode = "100644", otype = "blob", sha = a, name = "zzz"}}))
  assert(t1 == t2, "entry order does not matter: " .. t1 .. " vs " .. t2)
end

-- Zero entries builds the well-known empty tree — the shape a bounded
-- mutation's `refs/heads/board/seq` marker commit needs.
local function test_mktree_of_nothing_is_the_empty_tree()
  local root = fresh_repo("mktree-empty")
  local sha = check.must(gitobj.mktree(root, {}))
  assert(sha == "4b825dc642cb6eb9a060e54bf8d69288fbee4904", "got: " .. sha)
end

-- `commit_tree` carries independent author/committer identities and
-- the `Op:` trailer, exactly as `_work.store` needs for a real save.
local function test_commit_tree_carries_identity_and_trailer()
  local root = fresh_repo("commit-tree")
  local tree = check.must(gitobj.mktree(root, {}))
  local sha = check.must(gitobj.commit_tree(root, {
        tree = tree, parents = {}, message = "a test commit",
        author_name = "session-a", author_email = "session-a@board",
        committer_name = "Claude", committer_email = "noreply@anthropic.com",
        op = "new",
      }))
  local r = check.must(child.run({"git", "log", "-1",
        "--format=%an|%ae|%cn|%ce|%s%n%(trailers:key=Op,valueonly)", sha},
      {cwd = root}))
  assert(r.ok, "git log failed: " .. r.stderr)
  local first, rest = r.stdout:match("^([^\n]*)\n(.*)$")
  assert(first == "session-a|session-a@board|Claude|noreply@anthropic.com|"
    .. "a test commit", "got: " .. tostring(first))
  assert((rest:gsub("%s+$", "")) == "new", "the Op trailer: " .. tostring(rest))
end

-- `tree_of` reads a commit's own tree back.
local function test_tree_of_reads_a_commits_tree()
  local root = fresh_repo("tree-of")
  local tree = check.must(gitobj.mktree(root, {}))
  local sha = check.must(gitobj.commit_tree(root, {
        tree = tree, parents = {}, message = "m",
        author_name = "t", author_email = "t@b",
        committer_name = "t", committer_email = "t@b",
      }))
  assert(check.must(gitobj.tree_of(root, sha)) == tree)
end

-- `cat_file_batch` answers one entry per query, in order, keyed by the
-- query string — not the resolved sha — so the same content asked for
-- twice (two items sharing a blocker's reason blob) reads back as two
-- independent entries; and a missing path is simply absent.
local function test_cat_file_batch_keys_by_query_and_skips_missing()
  local root = fresh_repo("batch")
  local blob = check.must(gitobj.hash_object(root, "shared content"))
  local tree = check.must(gitobj.mktree(root,
      {{mode = "100644", otype = "blob", sha = blob, name = "a"},
        {mode = "100644", otype = "blob", sha = blob, name = "b"}}))
  local batch = check.must(gitobj.cat_file_batch(root,
      {tree .. ":a", tree .. ":b", tree .. ":no-such-path"}))
  assert(batch[tree .. ":a"].content == "shared content")
  assert(batch[tree .. ":b"].content == "shared content")
  assert(batch[tree .. ":no-such-path"] == nil, "a missing path is absent")
end

-- The raw tree parser: repeated `<mode> <name>\0<20 raw sha bytes>`,
-- with a subtree's mode spelled "40000" (no leading zero) and a
-- blob's "100644" — the two shapes `_work.itemtree` ever writes.
local function test_parse_tree_reads_blob_and_subtree_modes()
  local root = fresh_repo("parse-tree")
  local file_blob = check.must(gitobj.hash_object(root, "x"))
  local inner = check.must(gitobj.mktree(root,
      {{mode = "100644", otype = "blob", sha = file_blob, name = "inner-file"}}))
  local outer = check.must(gitobj.mktree(root,
      {{mode = "040000", otype = "tree", sha = inner, name = "subdir"},
        {mode = "100644", otype = "blob", sha = file_blob, name = "top-file"}}))
  local batch = check.must(gitobj.cat_file_batch(root, {outer}))
  local entries = gitobj.parse_tree(batch[outer].content)
  assert(#entries == 2, "two entries: " .. #entries)
  local by_name: {string: gitobj.TreeEntry} = {}
  for _, e in ipairs(entries) do
    by_name[e.name] = e
  end
  assert(by_name["subdir"] ~= nil and by_name["subdir"].mode == "40000"
    and by_name["subdir"].otype == "tree" and by_name["subdir"].sha == inner,
    "the subtree entry: " .. tostring(by_name["subdir"] and by_name["subdir"].sha))
  assert(by_name["top-file"] ~= nil and by_name["top-file"].mode == "100644"
    and by_name["top-file"].otype == "blob" and by_name["top-file"].sha == file_blob,
    "the blob entry")
end

-- Parsing round-trips through `mktree` itself: build a tree from N
-- entries, parse it back, and the entry set matches exactly (order
-- aside — git sorts by name, which `parse_tree` just reflects).
local function test_parse_tree_round_trips_through_mktree()
  local root = fresh_repo("parse-roundtrip")
  local names = {"alpha", "beta", "gamma", "delta", "epsilon"}
  local entries: {gitobj.TreeEntry} = {}
  local shas: {string: string} = {}
  for _, name in ipairs(names) do
    local sha = check.must(gitobj.hash_object(root, "content of " .. name))
    shas[name] = sha
    entries[#entries + 1] = {mode = "100644", otype = "blob", sha = sha, name = name}
  end
  local tree = check.must(gitobj.mktree(root, entries))
  local batch = check.must(gitobj.cat_file_batch(root, {tree}))
  local parsed = gitobj.parse_tree(batch[tree].content)
  assert(#parsed == #names, "same entry count: " .. #parsed)
  for _, e in ipairs(parsed) do
    assert(shas[e.name] == e.sha, "sha matches for " .. e.name)
    assert(e.mode == "100644" and e.otype == "blob")
  end
end
