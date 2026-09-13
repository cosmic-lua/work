#!/usr/bin/env cosmic
-- Format-4 to format-5 cutover: every item's one `spec.md` becomes the
-- `spec/` subtree, the fields its prose declared are filled, every other
-- section rides the migration commit's body, and one atomic prepared
-- transaction also advances the format marker.
local check = require("cosmic.check")
local child = require("cosmic.child")
local fixture = require("_work.fixture")
local format = require("_work.format")
local gitmigrate = require("_work.gitmigrate")
local migratecli = require("_work.gitmigrate_cli")
local gitobj = require("_work.gitobj")
local graph = require("_work.gitgraph")
local itemtree = require("_work.itemtree")
local prepared = require("_work.prepared")
local refs = require("_work.refs")
local specmod = require("_work.spec")
local store = require("_work.store")

--- The run's own clock — nothing inside the content below is this date.
local NOW < const > = 1700000000

--- A sidecar with every kind of section a format-4 spec carried: a
--- title, a Change with a `###` subsection naming paths, walls, an
--- Acceptance block to drop, and Evidence and Access to carry. The
--- Access section also carries the shapes the loose read-side rule
--- mistakes for repositories — a path fragment, a URL's tail, a file
--- with an extension — none of which may reach the field — and the
--- shapes the strict rule must still read: a declaration wrapped in
--- emphasis, a bare mention under an owner only a URL elsewhere on the
--- board vouches for, an SSH remote whose `.git` must not double it.
local RICH < const > = [[
# The leaf

## Change

Do the thing in `_work/a.tl` and `_work/b_test.tl`.

### Files

| `_work/c.tl` | grows |
| --- | --- |

## Non-goals

- not that

## Acceptance

Run it and watch.

## Evidence

Measured 2024-01-02: 1046 items, against https://github.com/vendor/lib.

## Access

- acme/other — `docs/decisions/d1-why.md`, and
  https://github.com/acme/upstream/blob/main/tool/net/x.c
- acme/self
- **Acme/Tool**: read-only (see bin/cosmic.pin), an either/or like
  algorithm/contract; vendor/lib-tools; git@github.com:acme/ssh.git
]]

local CHANGE_BLOB < const > = "Do the thing in `_work/a.tl` and `_work/b_test.tl`.\n\n"
.. "### Files\n\n| `_work/c.tl` | grows |\n| --- | --- |\n"

local BODY < const > = "# The leaf\n\n## Evidence\n\nMeasured 2024-01-02: 1046 items, "
.. "against https://github.com/vendor/lib.\n\n"
.. "## Access\n\n- acme/other — `docs/decisions/d1-why.md`, and\n"
.. "  https://github.com/acme/upstream/blob/main/tool/net/x.c\n- acme/self\n"
.. "- **Acme/Tool**: read-only (see bin/cosmic.pin), an either/or like\n"
.. "  algorithm/contract; vendor/lib-tools; git@github.com:acme/ssh.git"

local PLAIN < const > = "Just prose.\n\nMore of it.\n"

local function install_previous(root: string): string
  local current = check.must(refs.read_ref(root, "refs/heads/board/format"))
  local blob = check.must(gitobj.hash_object_write(root, format.PREVIOUS .. "\n"))
  local tree = check.must(gitobj.mktree_write(root, {
        {mode = "100644", otype = "blob", sha = blob, name = "format"},
      }))
  local prior = check.must(gitobj.commit_tree(root, {
        tree = tree, parents = {current}, message = "fixture format 4",
        author_name = "test", author_email = "test@example.com",
        committer_name = "test", committer_email = "test@example.com",
      }))
  assert(refs.update_ref(root, "refs/heads/board/format", prior, current))
  return prior
end

local function item_tips(root: string): {string: string}
  local found = check.must(refs.for_each_ref_raw(root,
      {"refs/heads/items", "refs/heads/ended"}))
  local out: {string: string} = {}
  for _, entry in ipairs(found) do out[entry.refname] = entry.sha end
  return out
end

local function nkeys(values: {string: string}): integer
  local n = 0
  for _ in pairs(values) do n = n + 1 end
  return n
end

local function show(root: string, sha: string, fmt: string): string
  local r = check.must(child.run({"git", "show", "-s", "--format=" .. fmt, sha},
      {cwd = root}))
  assert(r.ok, r.stderr)
  return (r.stdout:gsub("\n+$", ""))
end

--- Rewrite one item's tip into the format-4 shape: `repo`/`base`
--- collapsed into one `target` meta line, no `spec/` subtree, and
--- `body` as the single `spec.md` blob (none when "").
local function downgrade(root: string, id: string, body: string): string
  local target = "refs/heads/items/" .. id
  local prior = check.must(refs.read_ref(root, target))
  local old_tree = check.must(gitobj.tree_of(root, prior))
  local objects = check.must(gitobj.cat_file_batch(root, {old_tree, prior .. ":meta"}))
  local meta = assert(objects[prior .. ":meta"], "fixture item has meta")
  local parsed = itemtree.parse_meta(meta.content)
  local lines: {string} = {}
  for line in (meta.content .. "\n"):gmatch("([^\n]*)\n") do
    if line ~= "" and line:match("^repo: ") == nil and line:match("^base: ") == nil then
      lines[#lines + 1] = line .. "\n"
    end
  end
  local target_value = itemtree.format_target(parsed.repo or "", parsed.base or "")
  if target_value ~= "" then
    lines[#lines + 1] = "target: " .. target_value .. "\n"
  end
  local meta_sha = check.must(gitobj.hash_object_write(root, table.concat(lines)))
  local entries: {gitobj.TreeEntry} = {}
  for _, entry in ipairs(gitobj.parse_tree(objects[old_tree].content)) do
    if entry.name == "meta" then entry.sha = meta_sha end
    if entry.name ~= "spec" then entries[#entries + 1] = entry end
  end
  if body ~= "" then
    local blob = check.must(gitobj.hash_object_write(root, body))
    entries[#entries + 1] = {mode = "100644", otype = "blob", sha = blob, name = "spec.md"}
  end
  local tree = check.must(gitobj.mktree_write(root, entries))
  local commit = check.must(gitobj.commit_tree(root, {tree = tree,
        parents = {prior}, message = "fixture format 4 " .. id:sub(-8),
        author_name = "test", author_email = "test@example.com",
        committer_name = "test", committer_email = "test@example.com"}))
  assert(refs.update_ref(root, target, commit, prior))
  return commit
end

local record Board
  root: string
  leaf: string
  outcome: string
  marker: string
  before: {string: string}
end

--- A format-4 board: the leaf carries `RICH` (or `leaf_body`) and its
--- own repo, the outcome carries heading-less prose (or
--- `outcome_body`), the rest carry no `spec.md`.
local function format4_board(name: string, leaf_body?: string,
    outcome_body?: string): Board
  local s = fixture.init_state_repo(name)
  local outcome, leaf = fixture.root_with_leaf(s)
  assert(graph.cmd_set(s, leaf, nil, "acme/self", "main") == 0)
  check.must(store.close(s))
  downgrade(s.root, leaf, leaf_body or RICH)
  downgrade(s.root, outcome, outcome_body or PLAIN)
  local marker = install_previous(s.root)
  return {root = s.root, leaf = leaf, outcome = outcome, marker = marker,
    before = item_tips(s.root)}
end

local function test_local_migration_advances_every_ref_and_the_marker_at_now()
  local b = format4_board("migrate-local-v5")
  local outcome = check.must(gitmigrate.migrate(b.root, NOW))
  assert(outcome.applied and not outcome.current)
  assert(outcome.moved == nkeys(b.before), "every ref moves")
  local after = item_tips(b.root)
  for ref, old in pairs(b.before) do
    assert(after[ref] ~= old, "migration must advance: " .. ref)
    assert(show(b.root, after[ref], "%P") == old, "a first-parent successor")
    assert(show(b.root, after[ref], "%at %ct") == ("%d %d"):format(NOW, NOW),
      "both dates are the run's own")
    assert(show(b.root, after[ref], "%s") == ("migrate %s to format %s")
      :format(ref:sub(-8), format.CURRENT))
    local legacy = check.must(gitobj.cat_file_batch(b.root, {after[ref] .. ":spec.md"}))
    assert(next(legacy) == nil, "no spec.md survives: " .. ref)
  end
  assert(check.must(format.inspect(b.root)).content == format.blob())
  local again = check.must(gitmigrate.migrate(b.root))
  assert(again.current and again.applied and again.transaction == nil)
end

-- A batch: `limit` rewrites that many and leaves the marker where it
-- is, a rerun skips what landed and moves the rest with the marker, and
-- a third run reports current. A partial push is therefore never
-- clobbered by the run that follows it.
local function test_batches_skip_what_landed_and_move_the_marker_last()
  local b = format4_board("migrate-batch-v5")
  local total = nkeys(b.before)
  local first = check.must(gitmigrate.migrate(b.root, NOW, 2))
  assert(first.applied and first.moved == 2 and first.remaining == total - 2,
    ("moved=%d remaining=%d"):format(first.moved, first.remaining))
  assert(check.must(format.inspect(b.root)).content ~= format.blob(),
    "the marker waits for the last batch")
  local mid = item_tips(b.root)
  local second = check.must(gitmigrate.migrate(b.root, NOW))
  assert(second.skipped == 2 and second.moved == total - 2
    and second.remaining == 0, ("skipped=%d moved=%d"):format(second.skipped,
      second.moved))
  local after = item_tips(b.root)
  local untouched = 0
  for ref, sha in pairs(mid) do
    if sha ~= b.before[ref] then
      assert(after[ref] == sha, "a migrated tip is never rewritten: " .. ref)
      untouched = untouched + 1
    end
  end
  assert(untouched == 2, "the first batch's two tips survive as they landed")
  assert(check.must(format.inspect(b.root)).content == format.blob())
  local third = check.must(gitmigrate.migrate(b.root))
  assert(third.current, "and the third run is a no-op")
  -- `only` restricts a batch to one namespace; nothing here lives under
  -- `ended/`, so the selection is empty and refused rather than pushing
  -- a marker over unmigrated items.
  local c = format4_board("migrate-only-v5")
  local none, err = gitmigrate.migrate(c.root, NOW, 0, "ended")
  assert(none == nil and err:find("nothing to migrate", 1, true), err)
end

-- Batches write the same trees the single push writes. The owner set
-- `access` is filtered by comes from the whole board's prose; here the
-- leaf's Evidence carries the one URL vouching for `vendor`, and the
-- outcome's Access names `vendor/tool` bare. The leaf migrates first,
-- so one item at a time its `spec.md` is gone by the outcome's turn,
-- and only reading the migrated parent keeps the grant.
local function test_batches_write_the_trees_the_single_push_writes()
  local vouching = "## Evidence\n\nSee https://github.com/vendor/lib.\n\n"
  .. "## Access\n\n- vendor/tool\n"
  local bare = "## Change\n\nDo it.\n\n## Access\n\n- vendor/tool\n"
  local function access_of(root: string, id: string): string
    local tip = item_tips(root)["refs/heads/items/" .. id]
    local meta = check.must(gitobj.cat_file_batch(root, {tip .. ":meta"}))
    return (("\n" .. meta[tip .. ":meta"].content):match("\naccess: ([^\n]*)") or "")
  end
  local whole = format4_board("migrate-equiv-once-v5", vouching, bare)
  check.must(gitmigrate.migrate(whole.root, NOW))
  assert(access_of(whole.root, whole.leaf) == "vendor/tool"
    and access_of(whole.root, whole.outcome) == "vendor/tool",
    "one push grants both: " .. access_of(whole.root, whole.leaf) .. " / " .. access_of(whole.root, whole.outcome))
  local batched = format4_board("migrate-equiv-batched-v5", vouching, bare)
  for _ = 1, nkeys(batched.before) do
    check.must(gitmigrate.migrate(batched.root, NOW, 1))
  end
  assert(check.must(gitmigrate.migrate(batched.root)).current, "all moved")
  assert(access_of(batched.root, batched.leaf) == "vendor/tool"
    and access_of(batched.root, batched.outcome) == "vendor/tool",
    "one item at a time grants the same: " .. access_of(batched.root, batched.leaf))
end

local function test_leaf_prose_becomes_two_blobs_two_fields_and_a_body()
  local b = format4_board("migrate-leaf-v5")
  local outcome = check.must(gitmigrate.migrate(b.root, NOW))
  assert(outcome.with_change == 1 and outcome.with_non_goals == 1, "the leaf")
  assert(outcome.dropped == 1, "one Acceptance block dropped")
  local tip = item_tips(b.root)["refs/heads/items/" .. b.leaf]
  local blobs = check.must(gitobj.cat_file_batch(b.root,
      {tip .. ":spec/change.md", tip .. ":spec/non-goals.md"}))
  assert(blobs[tip .. ":spec/change.md"].content == CHANGE_BLOB,
    blobs[tip .. ":spec/change.md"].content)
  assert(blobs[tip .. ":spec/non-goals.md"].content == "- not that\n")
  local message = show(b.root, tip, "%B")
  assert(message:find("\n\n" .. BODY .. "\n\nOp: migrate", 1, true) ~= nil, message)
  assert(message:find("Acceptance", 1, true) == nil
    and message:find("Run it and watch", 1, true) == nil, message)
  local s = check.must(store.open(b.root))
  local it = check.must(store.load(s, b.leaf))
  assert(table.concat(it.touches, " ") == "_work/a.tl _work/b_test.tl _work/c.tl",
    table.concat(it.touches, " "))
  assert(table.concat(it.access, " ")
    == "acme/other acme/ssh acme/tool acme/upstream vendor/lib-tools",
    table.concat(it.access, " "))
  -- The loose read-side rule saw more than that; the write kept less.
  assert(specmod.declared_repos(RICH)["docs/decisions"]
    and specmod.declared_repos(RICH)["bin/cosmic.pin"]
    and specmod.declared_repos(RICH)["algorithm/contract"]
    and specmod.declared_repos(RICH)["acme/ssh.git"],
    "the read-side rule is still loose, which is why the write filters")
  assert(#it.depends_on == 0 and it.repo == "acme/self" and it.base == "main")
  assert(it.decode_problems == nil, table.concat(it.decode_problems or {}, "; "))
  check.must(store.close(s))
end

local function test_heading_less_prose_lands_wholly_in_the_body()
  local b = format4_board("migrate-plain-v5")
  local outcome = check.must(gitmigrate.migrate(b.root, NOW))
  assert(outcome.no_change == outcome.moved - 1, "every item but the leaf")
  assert(outcome.with_body == 2, "the leaf and the outcome")
  local tip = item_tips(b.root)["refs/heads/items/" .. b.outcome]
  local tree = check.must(gitobj.cat_file_batch(b.root, {tip .. ":spec"}))
  assert(next(tree) == nil, "no spec subtree at all for an empty record")
  assert(show(b.root, tip, "%B"):find("\n\nJust prose.\n\nMore of it.\n\nOp: migrate",
      1, true) ~= nil, show(b.root, tip, "%B"))
end

-- The whole-board proof `fsck` asks for: every migrated item, decoded
-- and re-encoded by this build, hashes to the tree it was written as.
local function test_every_migrated_item_re_encodes_to_its_own_tree()
  local b = format4_board("migrate-fsck-v5")
  check.must(gitmigrate.migrate(b.root, NOW))
  local tips = item_tips(b.root)
  local s = check.must(store.open(b.root))
  for _, it in ipairs(check.must(store.list(s))) do
    local tip = tips["refs/heads/items/" .. it.id]
    local rebuilt = check.must(itemtree.build_tree(s.root, it, store.read_spec(s, it.id)))
    assert(rebuilt == check.must(gitobj.tree_of(s.root, tip)),
      it.id:sub(-8) .. " does not re-encode to the tree it was read from")
  end
  check.must(store.close(s))
end

local function test_remote_migration_is_one_transaction_over_every_ref()
  local b = format4_board("migrate-remote-v5")
  local local_refs = check.must(refs.for_each_ref_raw(b.root,
      {"refs/heads/items", "refs/heads/ended", "refs/heads/board"}))
  for _, entry in ipairs(local_refs) do
    local tracking = check.must(refs.tracking_ref(entry.refname))
    assert(refs.update_ref(b.root, tracking, entry.sha, refs.ZERO_SHA))
  end
  assert(refs.set_board_mode(b.root, "remote"))
  local outcome = check.must(gitmigrate.migrate(b.root, NOW))
  assert(not outcome.applied and outcome.transaction ~= nil)
  local tx = outcome.transaction
  assert(#tx.updates == nkeys(b.before) + 1,
    "one transaction contains every item and the marker")
  local saw_format = false
  for _, update in ipairs(tx.updates) do
    if update.ref == "refs/heads/board/format" then
      saw_format = true
      assert(update.expected == b.marker)
    else
      assert(b.before[update.ref] == update.expected, update.ref)
    end
  end
  assert(saw_format)
  assert(show(b.root, tx.manifest, "%s") == ("migrate board format %s to %s")
    :format(format.PREVIOUS, format.CURRENT))
  assert(check.must(format.inspect(b.root)).content == format.PREVIOUS .. "\n")
  for ref, old in pairs(b.before) do assert(item_tips(b.root)[ref] == old) end
  assert(#check.must(prepared.list(b.root)) == 1, "one prepared transaction")
  -- The verb renders that transaction's push and stops at PREPARED.
  assert(migratecli.cmd_migrate(b.root, "origin", false) == 2)
end

local function test_migration_is_idempotent_and_refuses_unknown_predecessor()
  local s = fixture.init_state_repo("migrate-idempotent-v5")
  local current = check.must(gitmigrate.migrate(s.root))
  assert(current.current and current.applied and current.transaction == nil)
  assert(migratecli.cmd_migrate(s.root, "origin", false) == 0)

  local prior = check.must(refs.read_ref(s.root, "refs/heads/board/format"))
  local blob = check.must(gitobj.hash_object_write(s.root, "99\n"))
  local tree = check.must(gitobj.mktree_write(s.root, {
        {mode = "100644", otype = "blob", sha = blob, name = "format"},
      }))
  local unknown = check.must(gitobj.commit_tree(s.root, {tree = tree,
        parents = {prior}, message = "unknown format", author_name = "test",
        author_email = "test@example.com", committer_name = "test",
        committer_email = "test@example.com"}))
  assert(refs.update_ref(s.root, "refs/heads/board/format", unknown, prior))
  local denied, err = gitmigrate.migrate(s.root)
  assert(denied == nil and err:find("99", 1, true) ~= nil, err)
end
