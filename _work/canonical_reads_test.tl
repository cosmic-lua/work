#!/usr/bin/env cosmic
-- Canonical board reads have exactly two modes. A remote-backed board
-- reads only its caller-fetched `refs/remotes/<configured>/{items,ended,board}`
-- snapshot; local heads may be stale or hold unpublished successors.
-- Explicit local mode reads those heads. Prepared/staging namespaces
-- are never part of either snapshot and therefore never enter the
-- disposable cache.

local cache = require("_work.cache")
local check = require("cosmic.check")
local fixture = require("_work.fixture")
local gitobj = require("_work.gitobj")
local gitread = require("_work.gitread")
local gitreadmany = require("_work.gitreadmany")
local item = require("_work.item")
local itemtree = require("_work.itemtree")
local refs = require("_work.refs")
local store = require("_work.store")
local tail = require("_work.tail")

--- Copy the current local board snapshot into origin's remote-tracking
--- namespace. This stands in for a caller-run fetch; no remote is
--- needed for this read-path test.
local function seed_tracking(root: string, remote?: string)
  local found = check.must(refs.for_each_ref_raw(root,
      {"refs/heads/items", "refs/heads/ended", "refs/heads/board"}))
  for _, entry in ipairs(found) do
    local tracking = check.must(refs.tracking_ref(entry.refname, remote))
    assert(refs.update_ref(root, tracking, entry.sha, refs.ZERO_SHA))
  end
end

local function test_remote_reads_use_the_configured_non_origin_namespace()
  local seeded = fixture.init_state_repo("canonical-non-origin")
  local id = fixture.file_item(seeded, "configured upstream", "")
  seed_tracking(seeded.root, "upstream")
  assert(refs.set_board_remote(seeded.root, "upstream"))
  assert(refs.set_board_mode(seeded.root, "remote"))
  check.must(store.close(seeded))

  local s = check.must(store.open(seeded.root))
  local resolved = check.must(store.resolve(s, id:sub(1, 8)))
  assert(resolved == id, "ID resolution reads the configured tracking namespace")
  local loaded = check.must(store.load(s, resolved))
  assert(loaded.title == "configured upstream")
  local found = check.must(refs.for_each_ref(seeded.root,
      {"refs/heads/items", "refs/heads/board"}))
  assert(#found > 0, "canonical reader found the upstream snapshot")
  for _, entry in ipairs(found) do
    assert(entry.refname:match("^refs/heads/") ~= nil,
      "canonical names remain transport-neutral")
  end
  check.must(store.close(s))
end

--- A sibling successor of `parent`, carrying a changed title and prose.
local function variant(root: string, original: item.Item, parent: string,
    title: string, change: string): string
  local changed = check.must(store.snapshot_item(original))
  changed.title = title
  local tree = check.must(itemtree.build_tree(root, changed,
      {change = change, non_goals = ""}, true))
  return check.must(gitobj.commit_tree(root, {
        tree = tree, parents = {parent}, message = title,
        author_name = "test", author_email = "test@example.com",
        committer_name = "test", committer_email = "test@example.com",
      }))
end

local function title_of(items: {item.Item}, id: string): string
  for _, it in ipairs(items) do
    if it.id == id then
      return it.title
    end
  end
  return ""
end

local function test_remote_reads_ignore_local_heads_and_all_staging_refs()
  local seeded = fixture.init_state_repo("canonical-remote-reads")
  local id = fixture.file_item(seeded, "common base", "")
  seed_tracking(seeded.root)

  local loaded = check.must(gitread.load(seeded.root, id))
  local target = "refs/heads/items/" .. id
  local base = loaded.sha
  local local_sha = variant(seeded.root, loaded.it, base,
    "stale local head", "local spec\n")
  local remote_sha = variant(seeded.root, loaded.it, base,
    "confirmed remote head", "remote spec\n")
  assert(refs.update_ref(seeded.root, target, local_sha, base))
  local tracking = check.must(refs.tracking_ref(target))
  assert(refs.update_ref(seeded.root, tracking, remote_sha, base))

  -- A second valid item commit is reachable only from a staging ref.
  -- If a broad ref walk accidentally indexes staging, it appears on
  -- the board despite having no canonical item ref at all.
  local staged_id = fixture.file_item(seeded, "staging must stay hidden", "")
  local staged_target = "refs/heads/items/" .. staged_id
  local staged_sha = check.must(refs.read_ref(seeded.root, staged_target))
  assert(refs.update_ref(seeded.root,
      "refs/gitboard/prepared-test/" .. staged_id, staged_sha, refs.ZERO_SHA))
  assert(refs.update_ref(seeded.root, staged_target, refs.ZERO_SHA, staged_sha))

  assert(refs.set_board_mode(seeded.root, "remote"))
  check.must(store.close(seeded))

  local found = check.must(refs.for_each_ref(seeded.root,
      {"refs/heads/items", "refs/heads/ended", "refs/heads/board"}))
  for _, entry in ipairs(found) do
    assert(entry.refname:match("^refs/heads/") ~= nil,
      "canonical entries retain transport-neutral target names")
    assert(entry.refname:match("^refs/gitboard/") == nil,
      "a staging ref entered the canonical snapshot")
  end

  local one = check.must(gitread.load(seeded.root, id))
  assert(one.sha == remote_sha and one.it.title == "confirmed remote head")
  local many = check.must(gitreadmany.load_many(seeded.root, {id, staged_id}))
  assert(many[id] ~= nil and many[id].sha == remote_sha)
  assert(many[staged_id] == nil, "staging-only items are absent from batch reads")
  local resolved = check.must(tail.resolve_glob(seeded.root, tail.bare(id)))
  assert(resolved.sha == remote_sha, "tail resolution leases the fetched tip")

  local s = check.must(store.open(seeded.root))
  local listed = check.must(store.list(s))
  assert(title_of(listed, id) == "confirmed remote head")
  assert(title_of(listed, staged_id) == "", "staging-only item was indexed")
  assert(store.read_spec(s, id).change == "remote spec\n",
    "spec reads must dereference the remote-tracking ref too")

  local c = check.must(cache.open(seeded.root))
  local canonical = check.must(c.db:query_one(
      "SELECT title FROM items WHERE id = ?", {id}))
  assert(canonical.title == "confirmed remote head")
  local hidden = check.must(c.db:query_one(
      "SELECT COUNT(*) AS n FROM items WHERE id = ?", {staged_id}))
  assert(math.tointeger(hidden.n) == 0, "the cache indexed a staging-only item")
  check.must(cache.close(c))
  check.must(store.close(s))

  -- The same repository can opt into explicit local simulation mode;
  -- only then does its unpublished local successor become readable.
  assert(refs.set_board_mode(seeded.root, "local"))
  local local_store = check.must(store.open(seeded.root))
  local local_items = check.must(store.list(local_store))
  assert(title_of(local_items, id) == "stale local head")
  assert(store.read_spec(local_store, id).change == "local spec\n")
  assert(title_of(local_items, staged_id) == "",
    "staging refs are not canonical in local mode either")
  check.must(store.close(local_store))
end
