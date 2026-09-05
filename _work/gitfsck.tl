--- `fsck`: a read-only, offline whole-board audit — the problems no
--- other verb ever asks about because nothing else asks a WHOLE-board
--- question: an item's tree not re-encoding to what it was read from
--- (a hand edit, a canonical form that drifted), a `parent` or any
--- `edges/<kind>/<id>` naming an id that is not an item, an edge kind
--- this build does not interpret, more than one OPEN item claiming the
--- same key, a root carrying a `repo` it should never have, an id
--- filed under both `refs/heads/items` and `refs/heads/ended` at once
--- (the residue of a resolution whose atomic push landed the create
--- half of an old-style namespace move and lost the delete half — the
--- pushing credential can create and update a branch but never delete
--- one), and any item the store's own tolerant decode had to flag.
--- `store.list`'s own format check (`_work.gitread`) is the
--- board-readable precondition every other check here depends on — a
--- board this tool cannot even read is reported as the one problem it
--- is, nothing else asked. An `order` entry naming an id that is not a
--- child of the item carrying it, and a `refs/heads/board/order` entry
--- that is not a root, are audited here rather than in `item.problems`
--- or `_work.flow`: both need the whole board's own parent-child shape
--- to judge, which a single item's own fields cannot carry.
local flow = require("_work.flow")
local gate = require("_work.gitgate")
local gitobj = require("_work.gitobj")
local item = require("_work.item")
local itemtree = require("_work.itemtree")
local refs = require("_work.refs")
local store = require("_work.store")

--- The known edge kinds this build interprets — every OTHER kind an
--- item's `other_edges` names is reported once per item, since it is
--- carried opaquely rather than acted on by anything here.
local KNOWN_KINDS < const >: {string: boolean} = {
  beats = true, blocked_by = true,
}

--- The structural problems `all` carries — pure over an already-loaded
--- board, no git of its own: dangling `parent`/`order`/`beats`/
--- `blocked_by`/other-kind edges, an unknown edge kind, a key two open
--- items both claim, a root with a `repo`, and every item's own
--- `decode_problems`.
--- @param all {item.Item} Every item
--- @return {string} Problems, possibly empty
local function structural_problems(all: {item.Item}): {string}
  local index = flow.by_id(all)
  local out: {string} = {}
  local key_holder: {string: string} = {}
  for _, it in ipairs(all) do
    local id8 = it.id:sub(1, 8)
    if it.parent ~= "" and index[it.parent] == nil then
      out[#out + 1] = ("%s: parent %s does not exist"):format(id8, it.parent)
    end
    for _, o in ipairs(it.order or {}) do
      local child = index[o]
      if child == nil or child.parent ~= it.id then
        out[#out + 1] = ("%s: order names %s, which is not a child of it"):format(id8, o)
      end
    end
    for _, b in ipairs(it.beats or {}) do
      if index[b] == nil then
        out[#out + 1] = ("%s: beats %s, which is not an item"):format(id8, b)
      end
    end
    for _, b in ipairs(it.blocked_by or {}) do
      if index[b] == nil then
        out[#out + 1] = ("%s: blocked_by names %s, which is not an item"):format(id8, b)
      end
    end
    local other_kinds: {string} = {}
    for kind in pairs(it.other_edges or {}) do
      other_kinds[#other_kinds + 1] = kind
    end
    table.sort(other_kinds)
    for _, kind in ipairs(other_kinds) do
      if not KNOWN_KINDS[kind] then
        out[#out + 1] = ("%s: unknown edge kind %s"):format(id8, kind)
      end
      local ids: {string} = {}
      for eid in pairs((it.other_edges or {})[kind] or {}) do
        ids[#ids + 1] = eid
      end
      table.sort(ids)
      for _, eid in ipairs(ids) do
        if index[eid] == nil then
          out[#out + 1] = ("%s: %s names %s, which is not an item"):format(id8, kind, eid)
        end
      end
    end
    if item.is_open(it) and (it.key or "") ~= "" then
      local holder = key_holder[it.key]
      if holder ~= nil then
        out[#out + 1] = ("%s and %s: both open with key %s — at most one may be"):format(
          holder, id8, it.key)
      else
        key_holder[it.key] = id8
      end
    end
    if item.is_root(it) and (it.repo or "") ~= "" then
      out[#out + 1] = ("%s: a root carries repo %s — a root takes no repo"):format(
        id8, it.repo)
    end
    for _, p in ipairs(it.decode_problems or {}) do
      out[#out + 1] = ("%s: flagged: %s"):format(id8, p)
    end
  end
  return out
end

--- Whether one item's tree, re-encoded from its own decoded fields,
--- hashes IDENTICALLY to the tip it was read from — the canonical
--- round trip `_work/itemtree_test.tl` tests for one item, asked here
--- of every item on the board. nil when the item carries no observed
--- lease at all (unreachable through `store.list`, kept only so this
--- stays total). `itemtree.build_tree` here is the pure, non-writing
--- form (no `write` argument) — this is a read-only audit, so nothing
--- it computes needs to actually exist in the odb, only to hash the
--- same as what is already there.
--- @param s store.Store The store
--- @param it item.Item The item
--- @param spec_body string Its spec sidecar, "" when it has none
--- @param observed_trees {string: string} Every observed commit sha
--- (`s.leased_sha`) mapped to its tree sha, from ONE
--- `gitobj.tree_of_batch` call over the whole board
--- @return string | nil The problem
local function tree_problem(s: store.Store, it: item.Item, spec_body: string,
    observed_trees: {string: string}): string
  local observed_sha = s.leased_sha[it.id]
  if observed_sha == nil or observed_sha == "" then
    return nil
  end
  local observed_tree = observed_trees[observed_sha]
  if observed_tree == nil then
    return ("%s: could not read its observed tree"):format(it.id:sub(1, 8))
  end
  local rebuilt, berr = itemtree.build_tree(s.root, it, spec_body)
  if rebuilt == nil then
    return ("%s: could not re-encode its tree: %s"):format(it.id:sub(1, 8), berr)
  end
  if rebuilt ~= observed_tree then
    return ("%s: does not re-encode to the tree it was read from (%s vs %s) — "
      .. "canonical form drifted"):format(it.id:sub(1, 8), rebuilt:sub(1, 7),
      observed_tree:sub(1, 7))
  end
  return nil
end

--- `refs/heads/board/order`'s own findings: an entry naming an id that
--- is not an item, or is an item but not a root. Pure over an
--- already-loaded board and its observed root ranking — no git of its
--- own.
--- @param all {item.Item} Every item
--- @param root_order {string} The board's own root ranking
--- @return {string} Problems, possibly empty
local function root_order_problems(all: {item.Item}, root_order: {string}): {string}
  local index = flow.by_id(all)
  local out: {string} = {}
  for _, o in ipairs(root_order) do
    local named = index[o]
    if named == nil then
      out[#out + 1] = ("refs/heads/board/order: names %s, which is not an item"):format(o)
    elseif not item.is_root(named) then
      out[#out + 1] = ("refs/heads/board/order: names %s, which is not a root"):format(o)
    end
  end
  return out
end

--- The stale `refs/heads/board/lanes` finding: nothing writes it any more —
--- the lane observation lives in the cache database instead — but a
--- board carried over from before that move may still have one.
--- @param s store.Store The store
--- @return string | nil The problem, nil when the ref is not there
local function stale_lanes_ref_problem(s: store.Store): string | nil
  local found = refs.for_each_ref(s.root, {"refs/heads/board/lanes"})
  if found ~= nil and #found > 0 then
    return "refs/heads/board/lanes: stale — lane observations now live in "
    .. "the cache database (o/board.db), not a committed ref; delete it"
  end
  return nil
end

--- Run the whole audit and print it: one line per problem, then the
--- verdict line every other verb ends with.
--- @param s store.Store The store
--- @return integer Exit code
--- Branches under the item namespaces whose tail is not a KSUID: not
--- items, skipped by every read, and worth deleting.
--- @param s store.Store The store
--- @return {string} One line per stray ref
local function stray_ref_problems(s: store.Store): {string}
  local out: {string} = {}
  local found = refs.for_each_ref(s.root, {"refs/heads/items", "refs/heads/ended"})
  for _, r in ipairs(found or {}) do
    local tail = r.refname:match("/([^/]+)$") or ""
    if not (#tail == 27 and tail:match("^%w+$")) then
      out[#out + 1] = ("stray ref %s: not an item id; delete the branch"):format(r.refname)
    end
  end
  return out
end

--- One line per id `list` found filed under both `refs/heads/items`
--- and `refs/heads/ended` at once, naming which ref is being read and
--- the exact command a credential with delete rights runs to clear
--- the other — the push every ordinary session makes can create and
--- update a branch but never delete one, so this repair needs a
--- different credential.
--- @param s store.Store The store, after a `list` call
--- @return {string} One line per duplicate, possibly empty
local function duplicate_ref_problems(s: store.Store): {string}
  local out: {string} = {}
  for _, d in ipairs(store.duplicates(s)) do
    out[#out + 1] = ("%s: filed under both %s and %s — reading %s; clear the other "
      .. "with `git push origin --delete %s`"):format(
      d.id:sub(1, 8), d.kept_ref, d.dropped_ref, d.kept_ref, d.dropped_ref)
  end
  return out
end

local function cmd_fsck(s: store.Store): integer
  local all, lerr = store.list(s)
  if all == nil then
    print(lerr)
    return gate.verdict_line("fsck", false, "1 problem(s)")
  end
  local ids: {string} = {}
  local observed_shas: {string} = {}
  for _, it in ipairs(all) do
    ids[#ids + 1] = it.id
    local sha = s.leased_sha[it.id]
    if sha ~= nil and sha ~= "" then
      observed_shas[#observed_shas + 1] = sha
    end
  end
  local specs = store.read_specs(s, ids)
  local problems = structural_problems(all)
  for _, p in ipairs(root_order_problems(all, store.root_order(s))) do
    problems[#problems + 1] = p
  end
  -- One process for every item's observed tree, whatever the board's
  -- size — the batched form of `gitobj.tree_of`, which used to cost
  -- one `git rev-parse` PER item here.
  local observed_trees, terr = gitobj.tree_of_batch(s.root, observed_shas)
  if observed_trees == nil then
    problems[#problems + 1] = ("could not read observed trees: %s"):format(terr)
    observed_trees = {}
  end
  for _, it in ipairs(all) do
    local p = tree_problem(s, it, specs[it.id] or "", observed_trees)
    if p ~= nil then
      problems[#problems + 1] = p
    end
  end
  local lanes_p = stale_lanes_ref_problem(s)
  if lanes_p ~= nil then
    problems[#problems + 1] = lanes_p
  end
  for _, p in ipairs(duplicate_ref_problems(s)) do
    problems[#problems + 1] = p
  end
  for _, p in ipairs(stray_ref_problems(s)) do
    problems[#problems + 1] = p
  end
  for _, p in ipairs(problems) do
    print(p)
  end
  if #problems == 0 then
    return gate.verdict_line("fsck", true, ("ok (%d items)"):format(#all))
  end
  return gate.verdict_line("fsck", false, ("%d problem(s)"):format(#problems))
end

local record gitfsck
  structural_problems: function(all: {item.Item}): {string}
  cmd_fsck: function(s: store.Store): integer
end

local M: gitfsck = {
  structural_problems = structural_problems,
  cmd_fsck = cmd_fsck,
}

return M
