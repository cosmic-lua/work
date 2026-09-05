--- The store's read path: loading one item and listing the whole
--- board, each in a fixed number of git processes regardless of how
--- many items exist, and tolerating the one shape a half-landed
--- resolution can leave behind: an id filed under BOTH
--- `refs/heads/items` and `refs/heads/ended` at once, because the
--- pushing credential landed the create half of an old-style
--- namespace move and lost the delete half (it can create and update
--- a branch but never delete one). `load` and `list` each keep
--- exactly one entry per id when that happens (`pick_duplicate`,
--- exported for `_work.gitreadmany.load_many` to reuse the same rule);
--- `list` also reports every duplicate it found in `Board.duplicates`
--- so `_work.gitfsck` can name it for a human to clear. Split out of
--- `_work.store` to stay under its line cap; `_work.store` is the only
--- caller of `load`/`list` outside tests. `_work.gitreadmany.load_many`
--- — a named-id-set batch `_work.cache`'s fetch-path refresh uses — is
--- split out the same way, on the helpers this module exports below;
--- `_work.gitboardstate` holds the two board-level refs' own reading.
local cachedb = require("_work.cachedb")
local child = require("cosmic.child")
local format = require("_work.format")
local gitbatch = require("_work.gitbatch")
local gitboardstate = require("_work.gitboardstate")
local gitobj = require("_work.gitobj")
local item = require("_work.item")
local itemtree = require("_work.itemtree")
local refs = require("_work.refs")

--- One item as `load` found it: the item itself, and the ref and tip
--- it was read from — the lease a later `save` writes against.
local record Loaded
  it: item.Item
  ref: string
  sha: string
end

--- One id found under both `refs/heads/items` and `refs/heads/ended` —
--- the residue of a resolution whose atomic push landed the create
--- half of an old-style namespace move and lost the delete half.
--- `kept` is the ref `list`/`load` actually used; `dropped` is the
--- other one, still sitting on the remote, still worth clearing.
local record Duplicate
  id: string
  kept_ref: string
  kept_sha: string
  dropped_ref: string
  dropped_sha: string
end

--- The whole board as `list` found it: every item, its ref and tip
--- (`refs_by_id`/`shas_by_id` — the write lease for each),
--- `refs/heads/board/seq`'s own tip, every id `list` found filed under
--- both namespaces at once, and the digest of the `for-each-ref`
--- snapshot this pass took over exactly `_work.cachedb`'s watched
--- patterns — `_work.cache.open`'s check when a caller already has
--- this snapshot, never repeating the read. The board's own outcome
--- ranking is not a separate field here: it is one of `items`' own
--- `.order`, read the same way every item's is.
local record Board
  items: {item.Item}
  refs_by_id: {string: string}
  shas_by_id: {string: string}
  seq_sha: string
  duplicates: {Duplicate}
  refs_digest: string
end

--- Every `edges/<kind>` subtree an item's `sha:edges` entry names, as
--- `kind name -> subtree sha` — the shas a following batch must fetch
--- to learn each kind's own ids.
--- @param edges_content string The `edges` tree's raw bytes
--- @return {string: string} Kind name -> subtree sha
local function edge_kinds(edges_content: string): {string: string}
  local out: {string: string} = {}
  for _, e in ipairs(gitobj.parse_tree(edges_content)) do
    out[e.name] = e.sha
  end
  return out
end

--- Every blob sha whose CONTENT a kind's own ids need — every entry
--- across whichever kinds `kinds` names, marker or reason alike; a
--- marker's blob is simply "" once fetched.
--- @param kinds {string: string} Kind name -> subtree sha
--- @param kind_batch {string: gitobj.BatchEntry} Each subtree's own content
--- @return {string} Blob shas to fetch
local function content_blob_shas(kinds: {string: string},
    kind_batch: {string: gitobj.BatchEntry}): {string}
  local out: {string} = {}
  for _, sha in pairs(kinds) do
    local entry = kind_batch[sha]
    if entry ~= nil then
      for _, e in ipairs(gitobj.parse_tree(entry.content)) do
        out[#out + 1] = e.sha
      end
    end
  end
  return out
end

--- Build one item from its tip's `meta`/`held`/`order`/`edges` —
--- shared by `load` and `list`, each over their own
--- `gitbatch.batch_session`, so the tree-to-Item translation is
--- written once. `batch`, `kind_batch` and `blob_batch` are the
--- caller's already-read answers; nothing here starts a process.
--- @param id string The item id
--- @param sha string The tip commit this item's tree came from
--- @param batch {string: gitobj.BatchEntry} The meta/held/order/edges batch
--- @param kind_batch {string: gitobj.BatchEntry} Each edge kind's own
--- subtree content, by subtree sha
--- @param blob_batch {string: gitobj.BatchEntry} Every content blob (an
--- edge kind's own reason or marker), by blob sha
--- @return item.Item | nil The item
--- @return string Error message; set only when `meta` itself is missing
local function build_item(id: string, sha: string,
    batch: {string: gitobj.BatchEntry},
    kind_batch: {string: gitobj.BatchEntry},
    blob_batch: {string: gitobj.BatchEntry}): item.Item | nil, string
  local meta_entry = batch[sha .. ":meta"]
  if meta_entry == nil then
    return nil, ("%s: no meta at %s"):format(id, sha)
  end
  local meta = itemtree.parse_meta(meta_entry.content)
  local held = batch[sha .. ":held"] ~= nil
  local order_entry = batch[sha .. ":order"]
  local order = itemtree.parse_order(order_entry ~= nil and order_entry.content or "")
  local other_edges: {string: {string: string}} = {}
  local edges_entry = batch[sha .. ":edges"]
  if edges_entry ~= nil then
    for kind, ksha in pairs(edge_kinds(edges_entry.content)) do
      local kind_entry = kind_batch[ksha]
      if kind_entry ~= nil then
        local idmap: {string: string} = {}
        for _, e in ipairs(gitobj.parse_tree(kind_entry.content)) do
          local blob = blob_batch[e.sha]
          idmap[e.name] = blob ~= nil and blob.content or ""
        end
        other_edges[kind] = idmap
      end
    end
  end
  return itemtree.to_item(id, meta, held, order, other_edges)
end

--- Which of two refs for the same id — one under `refs/heads/items`, one
--- under `refs/heads/ended` — a reader should use: the one whose commit
--- descends from the other's, since that is the one still moving
--- forward; when neither descends from the other (a genuine fork, or
--- the ancestor check itself could not run), `ended/` wins, since a
--- resolved state is the safer default to read than a stale open one.
--- @param root string The repository root
--- @param items_e refs.RefEntry The refs/heads/items/<id> entry
--- @param ended_e refs.RefEntry The refs/heads/ended/<id> entry
--- @return refs.RefEntry The entry to keep
--- @return refs.RefEntry The entry to drop
local function pick_duplicate(root: string, items_e: refs.RefEntry,
    ended_e: refs.RefEntry): refs.RefEntry, refs.RefEntry
  if refs.is_ancestor(root, items_e.sha, ended_e.sha) then
    return ended_e, items_e
  end
  if refs.is_ancestor(root, ended_e.sha, items_e.sha) then
    return items_e, ended_e
  end
  return ended_e, items_e
end

--- Encode/decode `_work.store`'s one-shot lease ticket: an id already
--- resolved to its ref and sha (a prefix `resolve` matched, or a
--- handle resolved against a `list` snapshot), spent by the very next
--- `load` of that id; `lease_decode` gives "" for both when `ticket`
--- is "" or names a different id.
local function lease_encode(id: string, ref: string, sha: string): string
  return ("%s %s %s"):format(id, ref, sha)
end
local function lease_decode(ticket: string, id: string): string, string
  local tid, tref, tsha = ticket:match("^(%S+) (%S+) (%S+)$")
  if tid ~= id then
    return "", ""
  end
  return tref, tsha
end

--- Load one item by id, looking in `refs/heads/items` then `refs/heads/ended`,
--- resolving a rare double-filed id via `pick_duplicate`; `known_ref`/`known_sha`
--- skip that for-each-ref when already resolved (`_work.store.resolve`'s own
--- snapshot, or a prior `list`'s lease). The three rounds share one `gitbatch.batch_session`.
--- @param root string The repository root
--- @param id string Item id
--- @param known_ref string | nil The id's ref, already resolved
--- @param known_sha string | nil That ref's tip
--- @return Loaded | nil The item, its ref and its tip
--- @return string Error message; "no item <id>" when absent
local function load_item(root: string, id: string,
    known_ref?: string, known_sha?: string): Loaded | nil, string
  local ref, sha = known_ref, known_sha
  if ref == nil or ref == "" or sha == nil or sha == "" then
    local found, ferr = refs.for_each_ref(root, {"refs/heads/items/" .. id, "refs/heads/ended/" .. id})
    if found == nil then
      return nil, ferr
    end
    if #found == 0 then
      return nil, ("no item %s"):format(id)
    end
    ref, sha = found[1].refname, found[1].sha
    if #found > 1 then
      local items_e, ended_e = found[1], found[2]
      if items_e.refname ~= "refs/heads/items/" .. id then
        items_e, ended_e = ended_e, items_e
      end
      local kept = pick_duplicate(root, items_e, ended_e)
      ref, sha = kept.refname, kept.sha
    end
  end
  local sess, serr = gitbatch.batch_session(root)
  if sess == nil then
    return nil, serr
  end
  local batch, berr = sess:request({sha .. ":meta", sha .. ":held", sha .. ":order", sha .. ":edges"})
  if batch == nil then return gitbatch.session_fail(sess, berr) end
  local edges_entry = batch[sha .. ":edges"]
  local kinds: {string: string} = {}
  if edges_entry ~= nil then
    kinds = edge_kinds(edges_entry.content)
  end
  local kind_queries: {string} = {}
  for _, ksha in pairs(kinds) do
    kind_queries[#kind_queries + 1] = ksha
  end
  local kind_batch, kerr = sess:request(kind_queries)
  if kind_batch == nil then return gitbatch.session_fail(sess, kerr) end
  local blob_batch, rerr = sess:request(content_blob_shas(kinds, kind_batch))
  local _cok, cerr = sess:close()
  if blob_batch == nil then
    return nil, rerr
  end
  if not _cok then
    return nil, cerr
  end
  local it, ierr = build_item(id, sha, batch, kind_batch, blob_batch)
  if it == nil then
    return nil, ierr
  end
  return {it = it, ref = ref, sha = sha}
end

--- Every item in the store, done ones included: one `for-each-ref`
--- (also reading the two board-level refs' tips), then one
--- `gitbatch.batch_session` for all three rounds — every item's
--- `meta`/`held`/`order`/`edges` plus the format marker's, every edge
--- kind's own subtree content, and every content blob an edge kind's
--- own entry names — two processes total, never one per item or
--- round, PLUS one `merge-base --is-ancestor` for every id this pass
--- finds filed under both namespaces at once — rare, so it never
--- shows up in the fixed-process-count tests. The format check happens
--- here, once,
--- rather than in every reader: a board on a layout this tool cannot
--- trust is refused before anything else it read alongside it is
--- believed.
--- @param root string The repository root
--- @return Board | nil The board
--- @return string Error message naming the first genuinely corrupt
--- item, or the format refusal
local function list(root: string): Board | nil, string
  local found, ferr = refs.for_each_ref(root, {"refs/heads/items", "refs/heads/ended", "refs/heads/board"})
  if found == nil then
    return nil, ferr
  end
  local refs_digest = cachedb.digest_of(found)
  local items_by_id: {string: refs.RefEntry} = {}
  local ended_by_id: {string: refs.RefEntry} = {}
  local board_refs = gitboardstate.refs_new()
  for _, r in ipairs(found) do
    if not gitboardstate.absorb(board_refs, r.refname, r.sha) then
      local is_items = r.refname:sub(1, #"refs/heads/items/") == "refs/heads/items/"
      local is_ended = r.refname:sub(1, #"refs/heads/ended/") == "refs/heads/ended/"
      if is_items or is_ended then
        -- Only a KSUID-shaped tail is an item; anything else under the
        -- namespace is a stray branch `fsck` names and every read skips.
        local tail = r.refname:match("/([^/]+)$") or ""
        if #tail == 27 and tail:match("^%w+$") then
          if is_items then
            items_by_id[tail] = r
          else
            ended_by_id[tail] = r
          end
        end
      end
    end
  end
  -- Dedupe: an id present in both maps is the residue of a half-landed
  -- resolution (see the module doc) — keep the one `pick_duplicate`
  -- names and record the pair so `fsck` can report it; an id in only
  -- one map passes through untouched.
  local item_refs: {refs.RefEntry} = {}
  local duplicates: {Duplicate} = {}
  for id, items_e in pairs(items_by_id) do
    local ended_e = ended_by_id[id]
    if ended_e == nil then
      item_refs[#item_refs + 1] = items_e
    else
      local kept, dropped = pick_duplicate(root, items_e, ended_e)
      item_refs[#item_refs + 1] = kept
      duplicates[#duplicates + 1] = {id = id, kept_ref = kept.refname, kept_sha = kept.sha,
        dropped_ref = dropped.refname, dropped_sha = dropped.sha}
    end
  end
  for id, ended_e in pairs(ended_by_id) do
    if items_by_id[id] == nil then
      item_refs[#item_refs + 1] = ended_e
    end
  end
  table.sort(duplicates, function(a: Duplicate, b: Duplicate): boolean
      return a.id < b.id
    end)
  local queries: {string} = {}
  gitboardstate.append_queries(board_refs, queries)
  for _, r in ipairs(item_refs) do
    queries[#queries + 1] = r.sha .. ":meta"
    queries[#queries + 1] = r.sha .. ":held"
    queries[#queries + 1] = r.sha .. ":order"
    queries[#queries + 1] = r.sha .. ":edges"
  end
  local sess, serr = gitbatch.batch_session(root)
  if sess == nil then
    return nil, serr
  end
  local batch, berr = sess:request(queries)
  if batch == nil then return gitbatch.session_fail(sess, berr) end
  local format_content = gitboardstate.read(board_refs, batch)
  local frefusal = format.refusal(format_content, #item_refs > 0)
  if frefusal ~= nil then
    return gitbatch.session_fail(sess, frefusal)
  end
  local kinds_by_id: {string: {string: string}} = {}
  local kind_queries: {string} = {}
  for _, r in ipairs(item_refs) do
    local edges_entry = batch[r.sha .. ":edges"]
    if edges_entry ~= nil then
      local kinds = edge_kinds(edges_entry.content)
      kinds_by_id[r.refname] = kinds
      for _, ksha in pairs(kinds) do
        kind_queries[#kind_queries + 1] = ksha
      end
    end
  end
  local kind_batch, kerr = sess:request(kind_queries)
  if kind_batch == nil then return gitbatch.session_fail(sess, kerr) end
  local blob_queries: {string} = {}
  for _, r in ipairs(item_refs) do
    local kinds = kinds_by_id[r.refname]
    if kinds ~= nil then
      for _, sha in ipairs(content_blob_shas(kinds, kind_batch)) do
        blob_queries[#blob_queries + 1] = sha
      end
    end
  end
  local blob_batch, rerr = sess:request(blob_queries)
  local _cok, cerr = sess:close()
  if blob_batch == nil then
    return nil, rerr
  end
  if not _cok then
    return nil, cerr
  end
  local items: {item.Item} = {}
  local refs_by_id: {string: string} = {}
  local shas_by_id: {string: string} = {}
  for _, r in ipairs(item_refs) do
    local id = r.refname:match("^refs/heads/items/(.+)$") or r.refname:match("^refs/heads/ended/(.+)$")
    local it, ierr = build_item(id, r.sha, batch, kind_batch, blob_batch)
    if it == nil then
      return nil, ierr
    end
    items[#items + 1] = it
    refs_by_id[id] = r.refname
    shas_by_id[id] = r.sha
  end
  table.sort(items, function(a: item.Item, b: item.Item): boolean
      return a.id < b.id
    end)
  return {items = items, refs_by_id = refs_by_id, shas_by_id = shas_by_id,
    seq_sha = board_refs.seq_sha, duplicates = duplicates,
    refs_digest = refs_digest}
end

--- An item's spec sidecar, "" when absent, tried against every candidate
--- ref in order — `_work.store` passes the observed ref alone when known,
--- or both `refs/heads/items/<id>` and `refs/heads/ended/<id>` otherwise.
--- @param root string The repository root
--- @param candidates {string} Ref names to try, in order
--- @return string The spec markdown, possibly empty
local function read_spec(root: string, candidates: {string}): string
  for _, ref in ipairs(candidates) do
    local r = child.run({"git", "cat-file", "-p", ref .. ":spec.md"}, {cwd = root})
    if r ~= nil and r.ok then
      return r.stdout
    end
  end
  return ""
end

--- Every named item's spec sidecar in one batch, "" for an id that
--- has none or whose tip is unknown — the whole-board counterpart to
--- `read_spec`, so a readiness pass over every item costs one more
--- `cat-file --batch` instead of one process per item.
--- @param root string The repository root
--- @param shas_by_id {string: string} Each item's tip sha, from `list`
--- @param ids {string} Item ids to read, in any order
--- @return {string: string} Spec markdown by id, possibly empty
local function read_specs(root: string, shas_by_id: {string: string},
    ids: {string}): {string: string}
  local result: {string: string} = {}
  local queries: {string} = {}
  local query_of: {string: string} = {}
  for _, id in ipairs(ids) do
    result[id] = ""
    local sha = shas_by_id[id]
    if sha ~= nil then
      local q = sha .. ":spec.md"
      queries[#queries + 1] = q
      query_of[id] = q
    end
  end
  local batch = gitobj.cat_file_batch(root, queries)
  if batch == nil then
    return result
  end
  for _, id in ipairs(ids) do
    local q = query_of[id]
    if q ~= nil then
      local entry = batch[q]
      if entry ~= nil then
        result[id] = entry.content
      end
    end
  end
  return result
end

local record gitread
  type Loaded = Loaded
  type Board = Board
  type Duplicate = Duplicate
  lease_encode: function(id: string, ref: string, sha: string): string
  lease_decode: function(ticket: string, id: string): string, string
  load: function(root: string, id: string,
  known_ref?: string, known_sha?: string): Loaded | nil, string
  list: function(root: string): Board | nil, string
  read_spec: function(root: string, candidates: {string}): string
  read_specs: function(root: string, shas_by_id: {string: string},
  ids: {string}): {string: string}
  -- Exported only for `_work.gitreadmany.load_many` to reuse without
  -- duplicating this module's own read-path primitives.
  edge_kinds: function(edges_content: string): {string: string}
  content_blob_shas: function(kinds: {string: string},
  kind_batch: {string: gitobj.BatchEntry}): {string}
  build_item: function(id: string, sha: string,
  batch: {string: gitobj.BatchEntry}, kind_batch: {string: gitobj.BatchEntry},
  blob_batch: {string: gitobj.BatchEntry}): item.Item | nil, string
  pick_duplicate: function(root: string, items_e: refs.RefEntry,
  ended_e: refs.RefEntry): refs.RefEntry, refs.RefEntry
end

local M: gitread = {
  lease_encode = lease_encode,
  lease_decode = lease_decode,
  load = load_item,
  list = list,
  read_spec = read_spec,
  read_specs = read_specs,
  edge_kinds = edge_kinds,
  content_blob_shas = content_blob_shas,
  build_item = build_item,
  pick_duplicate = pick_duplicate,
}

return M
