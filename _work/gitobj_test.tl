#!/usr/bin/env cosmic
-- The git object plumbing `_work.store` builds on: computing blob and
-- tree ids in Lua with no process and nothing written (`hash_object`,
-- `mktree`) — differentially tested here against real git, since that
-- is the one place a mismatch would be silent and expensive — writing
-- them for real when a caller needs the object to exist
-- (`hash_object_write`, `mktree_write`), batch-reading objects back,
-- and parsing a raw tree object's bytes into entries.

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

--- The ground truth `hash_object` is tested against: real
--- `git hash-object --stdin`, deliberately WITHOUT `-w` — nothing
--- written, the same contract the pure form makes.
--- @param root string The repository root
--- @param content string The blob's bytes
--- @return string The blob's sha, real git's own answer
local function real_hash_object(root: string, content: string): string
  local r = check.must(child.run({"git", "hash-object", "--stdin"},
      {cwd = root, stdin = content}))
  assert(r.ok, "git hash-object failed: " .. r.stderr)
  return (r.stdout:gsub("%s+$", ""))
end

--- The ground truth `mktree` is tested against: real `git mktree`,
--- run directly (never through `_work.gitobj`) over the same entries.
--- Every entry's own object must already be written for real git to
--- resolve it — the well-known empty tree and empty blob excepted —
--- so a caller comparing against this writes its blobs with
--- `hash_object_write` first.
--- @param root string The repository root
--- @param entries {gitobj.TreeEntry} The tree's entries
--- @return string The tree's sha, real git's own answer
local function real_mktree(root: string, entries: {gitobj.TreeEntry}): string
  local lines: {string} = {}
  for _, e in ipairs(entries) do
    lines[#lines + 1] = ("%s %s %s\t%s\n"):format(e.mode, e.otype, e.sha, e.name)
  end
  local r = check.must(child.run({"git", "mktree"},
      {cwd = root, stdin = table.concat(lines)}))
  assert(r.ok, "git mktree failed: " .. r.stderr)
  return (r.stdout:gsub("%s+$", ""))
end

-- `hash_object` gives back exactly the id real `git hash-object`
-- (without `-w`) would, over content shapes that would break a naive
-- implementation: the empty string, ordinary text, and bytes no text
-- encoding would produce — embedded NULs and the full byte range.
local function test_hash_object_matches_real_git_hash_object()
  local root = fresh_repo("hash-differential")
  local cases: {string} = {
    "", "hello, board\n",
    "\0\1\2\3\255binary\0bytes\0embedded\0here\255\254",
    ("x"):rep(5000),
  }
  for i, content in ipairs(cases) do
    local got = check.must(gitobj.hash_object(root, content))
    local want = real_hash_object(root, content)
    assert(got == want, ("case %d, content of length %d: got %s want %s")
      :format(i, #content, got, want))
  end
end

-- The empty blob is the same well-known sha every git repository
-- agrees on — and `hash_object` gets there without writing anything.
local function test_hash_object_of_empty_matches_the_well_known_sha()
  local root = fresh_repo("empty-blob")
  local sha = check.must(gitobj.hash_object(root, ""))
  assert(sha == gitobj.EMPTY_BLOB_SHA, "got: " .. sha)
end

-- `hash_object_write` gives back the same sha as the pure form, and
-- ALSO actually lands the object — a second, real read finds it.
local function test_hash_object_write_writes_a_real_blob()
  local root = fresh_repo("hash-object-write")
  local pure_sha = check.must(gitobj.hash_object(root, "hello, board\n"))
  local sha = check.must(gitobj.hash_object_write(root, "hello, board\n"))
  assert(sha == pure_sha, "pure and writing forms agree: " .. sha .. " vs " .. pure_sha)
  local r = check.must(child.run({"git", "cat-file", "-p", sha}, {cwd = root}))
  assert(r.ok and r.stdout == "hello, board\n", "the blob reads back: "
    .. tostring(r.stdout))
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

-- The subtree ordering rule: a subtree named `edges` sorts as though
-- it carried a trailing "/", so it falls AFTER `edges-x` and
-- `edges.txt` — never where a plain byte-wise compare of "edges"
-- against "edges-x"/"edges.txt" would place it. Checked against real
-- `git mktree`, not merely asserted.
local function test_mktree_matches_real_git_on_subtree_ordering()
  local root = fresh_repo("mktree-ordering")
  local a = check.must(gitobj.hash_object_write(root, "a"))
  local b = check.must(gitobj.hash_object_write(root, "b"))
  local inner = check.must(gitobj.mktree_write(root,
      {{mode = "100644", otype = "blob", sha = a, name = "x"}}))
  local entries: {gitobj.TreeEntry} = {
    {mode = "100644", otype = "blob", sha = b, name = "edges.txt"},
    {mode = "40000", otype = "tree", sha = inner, name = "edges"},
    {mode = "100644", otype = "blob", sha = a, name = "edges-x"},
  }
  local want = real_mktree(root, entries)
  local got = check.must(gitobj.mktree(root, entries))
  assert(got == want, ("got %s want %s"):format(got, want))
end

-- A `held`-shaped tree: the empty blob every marker points at,
-- alongside an ordinary blob — the exact pair `_work.itemtree` writes
-- for a held item with no other edges.
local function test_mktree_matches_real_git_with_a_held_empty_blob()
  local root = fresh_repo("mktree-held")
  local held = check.must(gitobj.hash_object_write(root, ""))
  assert(held == gitobj.EMPTY_BLOB_SHA, "the empty blob's own well-known sha")
  local meta = check.must(gitobj.hash_object_write(root, "title: x\n"))
  local entries: {gitobj.TreeEntry} = {
    {mode = "100644", otype = "blob", sha = held, name = "held"},
    {mode = "100644", otype = "blob", sha = meta, name = "meta"},
  }
  local want = real_mktree(root, entries)
  local got = check.must(gitobj.mktree(root, entries))
  assert(got == want, ("got %s want %s"):format(got, want))
end

-- A nested tree: a subtree of a subtree, the shape `edges/<kind>`
-- always is. The inner tree's pure id is checked against real git
-- first, then written for real so the OUTER real `mktree` can resolve
-- it — mirroring how `_work.itemtree` builds one kind's subtree before
-- folding it into `edges`.
local function test_mktree_matches_real_git_for_a_nested_tree()
  local root = fresh_repo("mktree-nested")
  local leaf = check.must(gitobj.hash_object_write(root, "leaf content"))
  local inner_entries: {gitobj.TreeEntry} = {
    {mode = "100644", otype = "blob", sha = leaf, name = "file"},
  }
  local inner_want = real_mktree(root, inner_entries)
  local inner_got = check.must(gitobj.mktree(root, inner_entries))
  assert(inner_got == inner_want, ("inner: got %s want %s"):format(inner_got, inner_want))
  check.must(gitobj.mktree_write(root, inner_entries))
  local outer_entries: {gitobj.TreeEntry} = {
    {mode = "40000", otype = "tree", sha = inner_got, name = "inner"},
    {mode = "100644", otype = "blob", sha = leaf, name = "top"},
  }
  local outer_want = real_mktree(root, outer_entries)
  local outer_got = check.must(gitobj.mktree(root, outer_entries))
  assert(outer_got == outer_want, ("outer: got %s want %s"):format(outer_got, outer_want))
end

-- `commit_tree` carries independent author/committer identities and
-- the `Op:` trailer, exactly as `_work.store` needs for a real save.
-- Built on the empty tree, which git always resolves without it ever
-- being written.
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

-- `tree_of_batch` answers every commit's tree in ONE process,
-- including a commit sha repeated in the input.
local function test_tree_of_batch_reads_every_commits_tree()
  local root = fresh_repo("tree-of-batch")
  local trees: {string} = {}
  local commits: {string} = {}
  for i = 1, 3 do
    local tree = check.must(gitobj.mktree_write(root,
        {{mode = "100644", otype = "blob",
            sha = check.must(gitobj.hash_object_write(root, "n" .. tostring(i))),
            name = "f"}}))
    trees[i] = tree
    commits[i] = check.must(gitobj.commit_tree(root, {
          tree = tree, parents = {}, message = "c" .. tostring(i),
          author_name = "t", author_email = "t@b",
          committer_name = "t", committer_email = "t@b",
        }))
  end
  local batch = check.must(gitobj.tree_of_batch(root,
      {commits[1], commits[2], commits[3], commits[1]}))
  for i = 1, 3 do
    assert(batch[commits[i]] == trees[i],
      ("commit %d: got %s want %s"):format(i, tostring(batch[commits[i]]), trees[i]))
  end
end

-- Zero commits asks for nothing and gets nothing back, spawning no
-- process at all — the shape a board with no leased shas yet hits.
local function test_tree_of_batch_of_nothing_is_empty()
  local root = fresh_repo("tree-of-batch-empty")
  local batch = check.must(gitobj.tree_of_batch(root, {}))
  assert(next(batch) == nil, "no commits, no entries")
end

-- `cat_file_batch` answers one entry per query, in order, keyed by the
-- query string — not the resolved sha — so the same content asked for
-- twice (two items sharing a blocker's reason blob) reads back as two
-- independent entries; and a missing path is simply absent. Written
-- for real — a batch read needs the objects to actually be there.
local function test_cat_file_batch_keys_by_query_and_skips_missing()
  local root = fresh_repo("batch")
  local blob = check.must(gitobj.hash_object_write(root, "shared content"))
  local tree = check.must(gitobj.mktree_write(root,
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
-- Written for real — parsing reads the tree's own bytes back off git.
local function test_parse_tree_reads_blob_and_subtree_modes()
  local root = fresh_repo("parse-tree")
  local file_blob = check.must(gitobj.hash_object_write(root, "x"))
  local inner = check.must(gitobj.mktree_write(root,
      {{mode = "100644", otype = "blob", sha = file_blob, name = "inner-file"}}))
  local outer = check.must(gitobj.mktree_write(root,
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
-- Written for real, since the read-back goes through real git.
local function test_parse_tree_round_trips_through_mktree()
  local root = fresh_repo("parse-roundtrip")
  local names = {"alpha", "beta", "gamma", "delta", "epsilon"}
  local entries: {gitobj.TreeEntry} = {}
  local shas: {string: string} = {}
  for _, name in ipairs(names) do
    local sha = check.must(gitobj.hash_object_write(root, "content of " .. name))
    shas[name] = sha
    entries[#entries + 1] = {mode = "100644", otype = "blob", sha = sha, name = name}
  end
  local tree = check.must(gitobj.mktree_write(root, entries))
  local batch = check.must(gitobj.cat_file_batch(root, {tree}))
  local parsed = gitobj.parse_tree(batch[tree].content)
  assert(#parsed == #names, "same entry count: " .. #parsed)
  for _, e in ipairs(parsed) do
    assert(shas[e.name] == e.sha, "sha matches for " .. e.name)
    assert(e.mode == "100644" and e.otype == "blob")
  end
end
