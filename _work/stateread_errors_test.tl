#!/usr/bin/env cosmic
--- Corrupt native selection must never fall back to legacy refs or empty prose.
local cache = require("_work.cache")
local cachedb = require("_work.cachedb")
local check = require("cosmic.check")
local fixture = require("_work.fixture")
local fs = require("cosmic.fs")
local gitobj = require("_work.gitobj")
local gitreadspec = require("_work.gitreadspec")
local refs = require("_work.refs")
local store = require("_work.store")

local function commit(root: string, tree: string): string
  return check.must(gitobj.commit_tree(root, {tree = tree, parents = {}, message = "invalid native fixture",
        author_name = "test", author_email = "test@board", committer_name = "test", committer_email = "test@board"}))
end

local function test_missing_state_refuses_legacy_spec_and_cache_fallbacks()
  local s = fixture.init_state_repo("native-read-errors")
  local all = check.must(store.list(s))
  local id = all[1].id
  local tip = s.leased_sha[id]
  assert(store.close(s))
  assert(refs.update_ref(s.root, "refs/heads/state", refs.ZERO_SHA, s.state_head))
  local blob = check.must(gitobj.hash_object_write(s.root, "6\n"))
  local tree = check.must(gitobj.mktree_write(s.root, {{mode = "100644", otype = "blob", sha = blob, name = "format"}}))
  local marker = commit(s.root, tree)
  local old = check.must(refs.read_ref(s.root, "refs/heads/board/format"))
  assert(refs.update_ref(s.root, "refs/heads/board/format", marker, old))
  local reopened, err = store.open(s.root)
  assert(reopened == nil and err:find("requires refs/heads/state", 1, true) ~= nil, err)
  assert(gitreadspec.read_specs(s.root, {[id] = tip}, {id})[id] ~= nil,
    "explicit historical native prose remains readable without canonical refs")
  assert(fs.is_file(cachedb.path_of(s.root)))
  cache.after_fetch(s.root, "invalid")
  assert(not fs.is_present(cachedb.path_of(s.root)), "unknown format state invalidates the cache")
  local fetched, ferr = cache.around_fetch(s.root, function(): boolean, string return true, "" end)
  assert(not fetched and ferr:find("requires refs/heads/state", 1, true) ~= nil)
end

local function test_native_missing_meta_is_an_error_not_empty_spec()
  local legacy = fixture.init_state_repo("native-missing-meta")
  local id = check.must(store.list(legacy))[1].id
  assert(store.close(legacy))
  local text = check.must(gitobj.hash_object_write(legacy.root, "Readable prose is not proof of an item"))
  local prose = check.must(gitobj.mktree_write(legacy.root, {{mode = "100644", otype = "blob", sha = text, name = "change.md"}}))
  local malformed = check.must(gitobj.mktree_write(legacy.root, {{mode = "40000", otype = "tree", sha = prose, name = "spec"}}))
  local items = check.must(gitobj.mktree_write(legacy.root, {{mode = "40000", otype = "tree", sha = malformed, name = id}}))
  local blob = check.must(gitobj.hash_object_write(legacy.root, "6\n"))
  local tree = check.must(gitobj.mktree_write(legacy.root, {
        {mode = "100644", otype = "blob", sha = blob, name = "format"},
        {mode = "40000", otype = "tree", sha = items, name = "items"}}))
  local head = commit(legacy.root, tree)
  local old = check.must(refs.read_ref(legacy.root, "refs/heads/board/format"))
  assert(refs.update_ref(legacy.root, "refs/heads/board/format", head, old))
  assert(refs.update_ref(legacy.root, "refs/heads/state", head, legacy.state_head))
  local native = check.must(store.open(legacy.root))
  local one, one_err = pcall(function() store.read_spec(native, id) end)
  assert(not one and tostring(one_err):find("meta", 1, true) ~= nil, tostring(one_err))
  local many, many_err = pcall(function() store.read_specs(native, {id}) end)
  assert(not many and tostring(many_err):find("meta", 1, true) ~= nil, tostring(many_err))
  assert(store.close(native))
end
