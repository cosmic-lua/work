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

--- A fully-populated item — every scalar field set, plus beats,
--- blocked_by (with and without a reason), an edge kind this build
--- does not interpret, and builders/speccers — so the round trip has
--- everything to lose.
local function full_item(): item.Item
  local parent, beat1, beat2, block1, block2, other1 =
  fresh_id(), fresh_id(), fresh_id(), fresh_id(), fresh_id(), fresh_id()
  local it = check.must(item.decode({
        id = fresh_id(),
        title = "a fully populated item",
        parent = parent,
        repo = "cosmic-lua/cosmic",
        base = "main",
        key = "release.yml",
        beats = beat1 .. " " .. beat2,
        blocked_by = block1 .. " " .. block2,
        block_reason = {
          [block1] = "the API is not stable yet",
          [block2] = "",
        },
        claim = "session-a",
        builders = "session-a session-b",
        speccers = "session-c",
        reviewer = "session-d",
        pr = 42,
        verdict = "request changes",
        verdict_head = ("ab"):rep(20),
        verdict_spec = ("cd"):rep(20),
        is_held = false,
      }))
  it.other_edges = {relates = {[other1] = "context"}}
  return it
end

-- `encode_meta` writes every non-zero scalar field, one `key: value`
-- line each, `repo`/`base` collapsed into one `target` line — `beats`
-- and `blocked_by` are not among them; those are tree entries, and
-- neither is `held`, which is a marker blob, never a meta line.
local function test_meta_round_trips_every_scalar_field()
  local it = full_item()
  local text = itemtree.encode_meta(it)
  assert(not text:find("beats", 1, true), "beats is not a meta line")
  assert(not text:find("blocked_by", 1, true), "blocked_by is not a meta line")
  assert(not text:find("^held", 1, false) and not text:find("\nheld", 1, true),
    "held is not a meta line")
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
    {title = "t", target = "owner/name@a@b"}, false, {}, {}, {}, {})
  assert(item.is_flagged(decoded), "a malformed target flags the decode")
  local found = false
  for _, p in ipairs(decoded.decode_problems or {}) do
    if p:find("at most one @", 1, true) then
      found = true
    end
  end
  assert(found, table.concat(decoded.decode_problems or {}, "; "))
end

-- `held` is a marker blob, not a meta line: `encode_meta` never writes
-- it, and `to_item` takes it as a separate boolean the tree read
-- supplies from the blob's presence.
local function test_held_is_never_a_meta_line()
  local it = check.must(item.decode({id = fresh_id(), title = "a root"}))
  it.is_held = true
  local text = itemtree.encode_meta(it)
  assert(not text:find("held", 1, true), "held never rides in meta: " .. text)
  local held_it = itemtree.to_item(it.id, itemtree.parse_meta(text), true,
    {}, {}, {}, {})
  assert(held_it.is_held, "to_item takes held as its own argument")
end

-- The property the whole design rests on: decode a tree into an
-- Item, encode it straight back, and the tree sha must be IDENTICAL —
-- not merely equivalent content built differently. Round-tripped
-- twice, so a decode that quietly canonicalizes something (reordering
-- beats, say) would still be caught by the second pass staying stable.
local function test_canonical_round_trip_is_tree_sha_identical()
  local root = fresh_repo("roundtrip")
  local it = full_item()
  local tree1 = check.must(itemtree.build_tree(root, it, "## Change\nDo it.\n"))

  -- Read the tree back exactly the way `_work.gitread` does: meta,
  -- whether `held` is present, and every `edges/<kind>` subtree's own
  -- ids, with a blob-content batch for everything but `beats`.
  local batch = check.must(gitobj.cat_file_batch(root,
      {tree1 .. ":meta", tree1 .. ":held", tree1 .. ":edges"}))
  local meta = itemtree.parse_meta(batch[tree1 .. ":meta"].content)
  local held = batch[tree1 .. ":held"] ~= nil
  local kinds = gitobj.parse_tree(batch[tree1 .. ":edges"].content)
  local kind_queries: {string} = {}
  for _, k in ipairs(kinds) do
    kind_queries[#kind_queries + 1] = k.sha
  end
  local kind_batch = check.must(gitobj.cat_file_batch(root, kind_queries))
  local beats: {string} = {}
  local blocked_by: {string} = {}
  local reasons: {string: string} = {}
  local other_edges: {string: {string: string}} = {}
  local blob_queries: {string} = {}
  for _, k in ipairs(kinds) do
    if k.name ~= "beats" then
      for _, e in ipairs(gitobj.parse_tree(kind_batch[k.sha].content)) do
        blob_queries[#blob_queries + 1] = e.sha
      end
    end
  end
  local blob_batch = check.must(gitobj.cat_file_batch(root, blob_queries))
  for _, k in ipairs(kinds) do
    local ids = gitobj.parse_tree(kind_batch[k.sha].content)
    if k.name == "beats" then
      for _, e in ipairs(ids) do
        beats[#beats + 1] = e.name
      end
    elseif k.name == "blocked_by" then
      for _, e in ipairs(ids) do
        blocked_by[#blocked_by + 1] = e.name
        local re = blob_batch[e.sha]
        if re ~= nil and re.content ~= "" then
          reasons[e.name] = re.content
        end
      end
    else
      local idmap: {string: string} = {}
      for _, e in ipairs(ids) do
        local blob = blob_batch[e.sha]
        idmap[e.name] = blob ~= nil and blob.content or ""
      end
      other_edges[k.name] = idmap
    end
  end
  local decoded = itemtree.to_item(it.id, meta, held, beats, blocked_by, reasons,
    other_edges)
  assert(#(item.problems(decoded)) == 0,
    "the decoded item is content-valid: "
    .. table.concat(item.problems(decoded), "; "))
  local decoded_edges = decoded.other_edges
  assert(decoded_edges ~= nil and decoded_edges.relates ~= nil,
    "the unknown edge kind round-trips onto other_edges")

  local tree2 = check.must(itemtree.build_tree(root, decoded, "## Change\nDo it.\n"))
  assert(tree1 == tree2, "decode -> encode gives an identical tree sha: "
    .. tree1 .. " vs " .. tree2)

  -- A third pass off the second tree changes nothing further.
  local tree3 = check.must(itemtree.build_tree(root, decoded, "## Change\nDo it.\n"))
  assert(tree2 == tree3, "stable under a second round trip too")
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
