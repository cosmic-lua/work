#!/usr/bin/env cosmic
-- The canonical tree shape: `encode_meta`/`parse_meta` round-trip a
-- scalar field set exactly, `to_item` rebuilds an `item.Item` from a
-- tree's parts, and — the property the whole design rests on —
-- decoding a tree into an item and encoding it straight back gives
-- the IDENTICAL tree sha. A fresh git repository per test, since
-- `build_tree` needs somewhere to write real objects.

local check = require("cosmic.check")
local child = require("cosmic.child")
local env = require("cosmic.env")
local fastimport = require("_work.fastimport")
local fs = require("cosmic.fs")
local gitobj = require("_work.gitobj")
local item = require("_work.item")
local itemtree = require("_work.itemtree")
local ksuid = require("_work.ksuid")

local tmpdir = os.getenv("TEST_TMPDIR") or "/tmp"

local counter = 0

--- A fresh deterministic, well-formed id; later calls sort later.
local function fresh_id(): string
  counter = counter + 1
  return check.must(ksuid.encode(1700000000 + counter, ("\0"):rep(16)))
end

local hermetic_config < const > = fs.join(tmpdir, "gitconfig-empty")
assert(fs.write(hermetic_config, ""))
assert(env.set("GIT_CONFIG_GLOBAL", hermetic_config))
assert(env.set("GIT_CONFIG_NOSYSTEM", "1"))

--- A scratch git repository with nothing in it yet — `build_tree`'s
--- object writes need somewhere to land.
local function fresh_repo(name: string): string
  local root = fs.join(tmpdir, "itemtree-" .. name)
  assert(fs.remove_all(root))
  assert(fs.make_dirs(root))
  local r = check.must(child.run({"git", "init", "-q", root}))
  assert(r.ok, "git init failed: " .. r.stderr)
  return root
end

--- A fully-populated item — every scalar field set, plus a ranked
--- order, an edge kind this build does not interpret (with and
--- without a reason), and builders/speccers — so the round trip has
--- everything to lose.
local function full_item(): item.Item
  local parent, child1, child2, edge1, edge2 =
  fresh_id(), fresh_id(), fresh_id(), fresh_id(), fresh_id()
  local it = check.must(item.decode({
        id = fresh_id(),
        title = "a fully populated item",
        parent = parent,
        repo = "cosmic-lua/cosmic",
        base = "main",
        key = "release.yml",
        order = child1 .. " " .. child2,
        claim = "session-a",
        builders = "session-a session-b",
        speccers = "session-c",
        reviewer = "session-d",
        pr = 42,
        verdict = "request changes",
        verdict_head = ("ab"):rep(20),
        verdict_spec = ("cd"):rep(20),
      }))
  it.other_edges = {relates = {[edge1] = "context", [edge2] = ""}}
  return it
end

-- `encode_meta` writes every non-zero scalar field, one `key: value`
-- line each, `repo`/`base` collapsed into one `target` line — an edge
-- kind is not among them; that lives under `edges` entries, tree
-- content this file never touches.
local function test_meta_round_trips_every_scalar_field()
  local it = full_item()
  local text = itemtree.encode_meta(it)
  assert(not text:find("relates", 1, true), "an edge kind never rides in meta")
  assert(not text:find("^order", 1, false) and not text:find("\norder", 1, true),
    "order is not a meta line")
  local parsed = itemtree.parse_meta(text)
  assert(parsed.title == it.title)
  assert(parsed.parent == it.parent)
  assert(parsed.target == it.repo .. "@" .. it.base)
  assert(parsed.key == it.key)
  assert(parsed.claim == it.claim)
  assert(parsed.reviewer == it.reviewer)
  assert(parsed.pr == tostring(it.pr))
  assert(parsed.verdict == it.verdict)
  assert(parsed.verdict_head == it.verdict_head)
  assert(parsed.verdict_spec == it.verdict_spec)
  assert(parsed.builders == table.concat(it.builders, " "))
  assert(parsed.speccers == table.concat(it.speccers, " "))
end

-- Zero values are OMITTED, not written as empty: an item with nothing
-- set has an empty meta blob but for its required title.
local function test_meta_omits_zero_values()
  local it = check.must(item.decode({id = fresh_id(),
        title = "bare"}))
  local text = itemtree.encode_meta(it)
  assert(text == "title: bare\n", "got: " .. text)
end

-- `target` collapses `repo`/`base`: `owner/name` alone when there is
-- no base, `owner/name@branch` when both are set, and omitted (like
-- any other zero value) when both are empty.
local function test_target_combines_repo_and_base()
  local repo_only = check.must(item.decode({id = fresh_id(), title = "t",
        parent = fresh_id(), repo = "cosmic-lua/cosmic"}))
  assert(itemtree.encode_meta(repo_only):find(
      "target: cosmic%-lua/cosmic\n", 1, false) ~= nil,
    itemtree.encode_meta(repo_only))

  local both = check.must(item.decode({id = fresh_id(), title = "t",
        parent = fresh_id(), repo = "cosmic-lua/cosmic", base = "main"}))
  assert(itemtree.encode_meta(both):find(
      "target: cosmic%-lua/cosmic@main\n", 1, false) ~= nil,
    itemtree.encode_meta(both))

  local neither = check.must(item.decode({id = fresh_id(), title = "t"}))
  assert(not itemtree.encode_meta(neither):find("target", 1, true),
    "no target line when both are empty")
end

-- `parse_target`'s inverse, including the round trip through
-- `to_item`, and its one refusal: more than one `@` is a decode
-- problem, not a hard failure — the malformed value still decodes.
local function test_parse_target_round_trips_and_refuses_extra_at()
  local repo, base, err = itemtree.parse_target("owner/name@branch")
  assert(repo == "owner/name" and base == "branch" and err == "", err)

  local repo2, base2, err2 = itemtree.parse_target("owner/name")
  assert(repo2 == "owner/name" and base2 == "" and err2 == "", err2)

  local repo3, base3, err3 = itemtree.parse_target("")
  assert(repo3 == "" and base3 == "" and err3 == "", err3)

  local _repo4, _base4, err4 = itemtree.parse_target("owner/name@a@b")
  assert(err4 ~= "" and err4:find("at most one @", 1, true) ~= nil, err4)

  local decoded = itemtree.to_item(fresh_id(),
    {title = "t", target = "owner/name@a@b"}, false, {}, {})
  assert(item.is_flagged(decoded), "a malformed target flags the decode")
  local found = false
  for _, p in ipairs(decoded.decode_problems or {}) do
    if p:find("at most one @", 1, true) then
      found = true
    end
  end
  assert(found, table.concat(decoded.decode_problems or {}, "; "))
end

-- `held` is a marker blob at the tree root, unknown to this build:
-- there is no field left for `encode_meta` to write it from, and
-- `to_item` turns its presence into a decode problem rather than a
-- field, without failing the read.
local function test_held_marker_is_an_unknown_decode_problem()
  local it = check.must(item.decode({id = fresh_id(), title = "a root"}))
  local text = itemtree.encode_meta(it)
  local held_it = itemtree.to_item(it.id, itemtree.parse_meta(text), true, {}, {})
  assert(item.is_flagged(held_it), "a held marker flags the decode")
  local found = false
  for _, p in ipairs(held_it.decode_problems or {}) do
    if p:find("held", 1, true) then
      found = true
    end
  end
  assert(found, table.concat(held_it.decode_problems or {}, "; "))
end

--- Read one tree back exactly the way `_work.gitread.build_item` does:
--- meta, whether `held` is present, the `order` blob when there is
--- one, and every `edges/<kind>` subtree's own ids and content — this
--- build interprets no kind, so every entry's content is fetched and
--- landed on `other_edges` uniformly.
--- @param root string The repository root
--- @param tree_sha string The tree to read
--- @return {string: string} meta `parse_meta`'s output
--- @return boolean held Whether a `held` marker blob was present
--- @return {string} order This tree's ranked children
--- @return {string: {string: string}} other_edges Every edge kind found
local function read_tree(root: string, tree_sha: string):
  {string: string}, boolean, {string}, {string: {string: string}}
  local batch = check.must(gitobj.cat_file_batch(root,
      {tree_sha .. ":meta", tree_sha .. ":held", tree_sha .. ":order",
        tree_sha .. ":edges"}))
  local meta = itemtree.parse_meta(batch[tree_sha .. ":meta"].content)
  local held = batch[tree_sha .. ":held"] ~= nil
  local order: {string} = {}
  local order_entry = batch[tree_sha .. ":order"]
  if order_entry ~= nil then
    order = itemtree.parse_order(order_entry.content)
  end
  local other_edges: {string: {string: string}} = {}
  local edges_entry = batch[tree_sha .. ":edges"]
  if edges_entry ~= nil then
    local kinds = gitobj.parse_tree(edges_entry.content)
    local kind_queries: {string} = {}
    for _, k in ipairs(kinds) do
      kind_queries[#kind_queries + 1] = k.sha
    end
    local kind_batch = check.must(gitobj.cat_file_batch(root, kind_queries))
    local blob_queries: {string} = {}
    for _, k in ipairs(kinds) do
      for _, e in ipairs(gitobj.parse_tree(kind_batch[k.sha].content)) do
        blob_queries[#blob_queries + 1] = e.sha
      end
    end
    local blob_batch = check.must(gitobj.cat_file_batch(root, blob_queries))
    for _, k in ipairs(kinds) do
      local idmap: {string: string} = {}
      for _, e in ipairs(gitobj.parse_tree(kind_batch[k.sha].content)) do
        local blob = blob_batch[e.sha]
        idmap[e.name] = blob ~= nil and blob.content or ""
      end
      other_edges[k.name] = idmap
    end
  end
  return meta, held, order, other_edges
end

-- The property the whole design rests on: decode a tree into an
-- Item, encode it straight back, and the tree sha must be IDENTICAL —
-- not merely equivalent content built differently. Round-tripped
-- twice, so a decode that quietly canonicalizes something (reordering
-- an edge kind's ids, say) would still be caught by the second pass
-- staying stable.
local function test_canonical_round_trip_is_tree_sha_identical()
  local root = fresh_repo("roundtrip")
  local it = full_item()
  -- Written for real: the read-back below goes through
  -- `cat_file_batch`, a real `git cat-file`, which needs the objects
  -- to actually be in this repository's odb.
  local tree1 = check.must(itemtree.build_tree(root, it, "## Change\nDo it.\n", true))

  local meta, held, order, other_edges = read_tree(root, tree1)
  local decoded = itemtree.to_item(it.id, meta, held, order, other_edges)
  assert(#(item.problems(decoded)) == 0,
    "the decoded item is content-valid: "
    .. table.concat(item.problems(decoded), "; "))
  local decoded_edges = decoded.other_edges
  assert(decoded_edges ~= nil and decoded_edges.relates ~= nil,
    "the unknown edge kind round-trips onto other_edges")
  assert(#decoded.order == 2 and decoded.order[1] == it.order[1]
    and decoded.order[2] == it.order[2],
    "order round-trips in rank order: " .. table.concat(decoded.order, ","))

  local tree2 = check.must(itemtree.build_tree(root, decoded, "## Change\nDo it.\n"))
  assert(tree1 == tree2, "decode -> encode gives an identical tree sha: "
    .. tree1 .. " vs " .. tree2)

  -- A third pass off the second tree changes nothing further.
  local tree3 = check.must(itemtree.build_tree(root, decoded, "## Change\nDo it.\n"))
  assert(tree2 == tree3, "stable under a second round trip too")
end

-- An OLD-layout tree — `edges/beats/<id>` (an empty marker),
-- `edges/blocked_by/<id>` (a reason), and a `held` blob at the tree
-- root — is exactly what the migrate verb (the next slice) will read:
-- this build interprets neither kind nor the marker, so `beats` and
-- `blocked_by` land in `other_edges` with their content unchanged,
-- `held`'s presence is a decode problem rather than a field, and the
-- EDGES half of the tree re-encodes byte for byte from the decoded
-- item — the `held` blob itself does not, since nothing here writes
-- one any more; that asymmetry is exactly what makes `held` a decode
-- problem and not a round-tripped field.
local function test_old_layout_tree_edges_and_held_marker()
  local root = fresh_repo("old-layout")
  local beat_id = fresh_id()
  local blocker_id = fresh_id()

  local meta_sha = check.must(gitobj.hash_object_write(root, "title: an old item\n"))
  local held_sha = check.must(gitobj.hash_object_write(root, ""))
  local beat_marker_sha = check.must(gitobj.hash_object_write(root, ""))
  local blocker_reason_sha = check.must(gitobj.hash_object_write(root,
      "the API is not stable yet"))
  local beats_tree_sha = check.must(gitobj.mktree_write(root,
      {{mode = "100644", otype = "blob", sha = beat_marker_sha, name = beat_id}}))
  local blocked_tree_sha = check.must(gitobj.mktree_write(root,
      {{mode = "100644", otype = "blob", sha = blocker_reason_sha, name = blocker_id}}))
  local edges_sha = check.must(gitobj.mktree_write(root, {
        {mode = "40000", otype = "tree", sha = beats_tree_sha, name = "beats"},
        {mode = "40000", otype = "tree", sha = blocked_tree_sha, name = "blocked_by"},
      }))
  local old_tree_sha = check.must(gitobj.mktree_write(root, {
        {mode = "100644", otype = "blob", sha = meta_sha, name = "meta"},
        {mode = "100644", otype = "blob", sha = held_sha, name = "held"},
        {mode = "40000", otype = "tree", sha = edges_sha, name = "edges"},
      }))

  local meta, held, order, other_edges = read_tree(root, old_tree_sha)
  local id = fresh_id()
  local decoded = itemtree.to_item(id, meta, held, order, other_edges)

  local decoded_edges = decoded.other_edges
  assert(decoded_edges ~= nil, "the edges land in other_edges")
  assert(decoded_edges.beats ~= nil and decoded_edges.beats[beat_id] == "",
    "the beats marker's id and empty content survive")
  assert(decoded_edges.blocked_by ~= nil
    and decoded_edges.blocked_by[blocker_id] == "the API is not stable yet",
    "the blocked_by reason survives")

  assert(item.is_flagged(decoded), "the held marker flags the decode")
  local found = false
  for _, p in ipairs(decoded.decode_problems or {}) do
    if p:find("held", 1, true) then
      found = true
    end
  end
  assert(found, table.concat(decoded.decode_problems or {}, "; "))

  local rebuilt_sha = check.must(itemtree.build_tree(root, decoded, "", true))
  local orig_edges = check.must(gitobj.cat_file_batch(root, {old_tree_sha .. ":edges"}))
  local rebuilt_edges = check.must(gitobj.cat_file_batch(root, {rebuilt_sha .. ":edges"}))
  assert(orig_edges[old_tree_sha .. ":edges"].content
    == rebuilt_edges[rebuilt_sha .. ":edges"].content,
    "beats and blocked_by re-encode byte for byte")
end

-- `spec.md` is present only when a non-empty body is given — an
-- absent sidecar and an empty-string one are the same tree.
local function test_spec_md_is_omitted_when_empty_or_nil()
  local root = fresh_repo("spec-omit")
  local it = check.must(item.decode({id = fresh_id(),
        title = "no spec"}))
  local nil_tree = check.must(itemtree.build_tree(root, it, nil))
  local empty_tree = check.must(itemtree.build_tree(root, it, ""))
  assert(nil_tree == empty_tree, "nil and \"\" build the same tree")
end

-- `_work.gitwrite` builds every item's commit through
-- `_work.fastimport` instead of this file's `hash-object`/`mktree`
-- chain — the property the whole switch rests on is that BOTH paths
-- land the identical tree sha for the same item, since a git tree is
-- canonical (the same final (mode, name, blob) entries hash the same
-- regardless of how they were assembled). A brand-new item — `old`
-- nil, every path "added" — is the fullest exercise of `diff_item`.
local function test_fast_import_tree_matches_mktree_tree()
  local root = fresh_repo("fastimport-roundtrip")
  local it = full_item()
  local spec = "## Change\nDo it.\n"
  local mktree_sha = check.must(itemtree.build_tree(root, it, spec))

  local ops = fastimport.diff_item(nil, it, spec, "")
  assert(#ops > 0, "a brand-new item has paths to write")
  local plan: fastimport.CommitPlan = {
    ref = "refs/fastimport-check/x", from = nil,
    author_name = "Test", author_email = "test@example.com",
    author_date = "1700000000 +0000", committer_name = "Claude",
    committer_email = "noreply@anthropic.com", committer_date = "1700000000 +0000",
    message = "check", op = "", ops = ops,
  }
  assert(fastimport.run(root, {plan}))
  local r = check.must(child.run(
      {"git", "rev-parse", "refs/fastimport-check/x^{tree}"}, {cwd = root}))
  assert(r.ok, "git rev-parse failed: " .. r.stderr)
  local fi_tree = (r.stdout:gsub("%s+$", ""))
  assert(fi_tree == mktree_sha,
    ("fast-import's tree must match mktree's byte for byte: %s vs %s")
    :format(fi_tree, mktree_sha))
end
