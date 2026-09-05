--- An item's canonical git tree: the `meta` text blob, the optional
--- `spec.md` sidecar, the optional `order` blob, the `held` marker
--- blob, and the `edges/<kind>/<id>` entries — and the two directions
--- between that tree and an `_work.item.Item`. This is the ONE place
--- that shape is written, so `_work.store`'s writer and reader, and
--- the round-trip test, all agree on it by construction.
---
--- `meta` carries every scalar field as one `key: value` line, keys in
--- the order below; a zero value — "", 0, an empty list — is OMITTED,
--- so two items differing only in which fields are unset differ in
--- their tree too. `repo`/`base` collapse into one `target` line,
--- written `owner/name@branch`, `owner/name` alone when `base` is
--- empty, and omitted when both are empty (`format_target`/
--- `parse_target`). `held` is not a meta line at all: an empty marker
--- blob at the path `held`, present exactly when `is_held` is true.
--- `order` is not a meta line either: one blob, child ids one per
--- line with a trailing newline, present only when this item has
--- ranked at least one child (`encode_order`/`parse_order` — the same
--- shape `refs/heads/board/order` carries for the board's own roots).
--- `beats` and `blocked_by` are tree entries rather than meta lines
--- because each entry is itself content: an empty marker blob for a
--- beaten id, a reason blob for a blocker — both live under one
--- `edges` subtree, alongside any OTHER kind this reader does not
--- interpret (`item.Item.other_edges`), so a kind this build predates
--- round-trips through it unchanged. Git sorts a tree's own entries by
--- name, so decoding one back loses whatever ORDER the fields were
--- written in — immaterial here, since every reader of an edge kind
--- treats it as a set, never a sequence.
local gitobj = require("_work.gitobj")
local item = require("_work.item")

--- Scalar meta keys, in the order they are written. `target` (the
--- combined `repo`/`base`) sits where `_work.item.Item` declares
--- `parent`'s neighbor; `id`, `beats`, `blocked_by` and `held` are not
--- `meta` lines at all.
local META_KEYS < const >: {string} = {
  "title", "parent", "target", "key", "claim", "reviewer", "pr",
  "result", "verdict", "verdict_head", "verdict_spec", "resolution",
  "builders", "speccers",
}

--- Combine `repo`/`base` into one `target` line's value: `owner/name`
--- alone when there is no base, `owner/name@branch` when both are
--- set, `@branch` when a base stands with no repo (an unusual but
--- legal combination `item.problems` does not itself forbid), and ""
--- when both are empty — `put`'s own zero check then omits the line
--- entirely. The inverse of `parse_target`.
--- @param repo string The repo, "" when unset
--- @param base string The base branch, "" when unset
--- @return string The `target` line's value
local function format_target(repo: string, base: string): string
  if repo == "" and base == "" then
    return ""
  end
  if base == "" then
    return repo
  end
  return repo .. "@" .. base
end

--- Split a `target` line's value back into `repo`/`base`. A target
--- with more than one `@` is malformed — `to_item` folds the message
--- this returns into the decoded item's `.decode_problems` rather than
--- failing the read outright, the same tolerance every other content
--- problem gets.
--- @param target string The `target` line's value, "" when absent
--- @return string repo
--- @return string base
--- @return string A problem message; "" when `target` parsed cleanly
local function parse_target(target: string): string, string, string
  if target == "" then
    return "", "", ""
  end
  local at1 = target:find("@", 1, true)
  if at1 == nil then
    return target, "", ""
  end
  local at2 = target:find("@", at1 + 1, true)
  if at2 ~= nil then
    return target:sub(1, at1 - 1), target:sub(at1 + 1),
    ("target must have at most one @: %s"):format(target)
  end
  return target:sub(1, at1 - 1), target:sub(at1 + 1), ""
end

--- The `order` blob's text for a ranked list of ids: one per line,
--- trailing newline, "" when the list is empty — the shared shape an
--- item's own `order` blob and `refs/heads/board/order` both carry.
--- @param ids {string} Ranked ids, in rank order
--- @return string The blob text, "" for an empty list
local function encode_order(ids: {string}): string
  local parts: {string} = {}
  for _, id in ipairs(ids) do
    parts[#parts + 1] = id .. "\n"
  end
  return table.concat(parts)
end

--- Parse an `order` blob's text back into ranked ids. A blank line is
--- skipped rather than read as an empty id, so trailing whitespace in
--- a hand-edited blob does not become a phantom entry.
--- @param text string The blob's content
--- @return {string} Ranked ids, in rank order
local function parse_order(text: string): {string}
  local out: {string} = {}
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    if line ~= "" then
      out[#out + 1] = line
    end
  end
  return out
end

--- The `meta` blob's text for one item. Every key in `META_KEYS`
--- either contributes one `key: value\n` line or is skipped outright
--- when its value is zero.
--- @param it item.Item The item
--- @return string The meta text
local function encode_meta(it: item.Item): string
  local parts: {string} = {}
  local function put(key: string, value: string)
    if value ~= "" then
      parts[#parts + 1] = key .. ": " .. value .. "\n"
    end
  end
  put("title", it.title or "")
  put("parent", it.parent or "")
  put("target", format_target(it.repo or "", it.base or ""))
  put("key", it.key or "")
  put("claim", it.claim or "")
  put("reviewer", it.reviewer or "")
  if (it.pr or 0) ~= 0 then
    parts[#parts + 1] = ("pr: %d\n"):format(it.pr)
  end
  put("result", it.result or "")
  put("verdict", it.verdict or "")
  put("verdict_head", it.verdict_head or "")
  put("verdict_spec", it.verdict_spec or "")
  put("resolution", it.resolution or "")
  if #(it.builders or {}) > 0 then
    parts[#parts + 1] = "builders: " .. table.concat(it.builders, " ") .. "\n"
  end
  if #(it.speccers or {}) > 0 then
    parts[#parts + 1] = "speccers: " .. table.concat(it.speccers, " ") .. "\n"
  end
  return table.concat(parts)
end

--- Parse `meta` text into a flat key -> value map. A line that does
--- not match `key: value` is skipped rather than refused — the same
--- forward tolerance `item.decode` gives an unknown literal key — so a
--- field this reader predates still reads the rest of the item.
--- @param text string The meta blob's content
--- @return {string: string} Raw key -> value
local function parse_meta(text: string): {string: string}
  local out: {string: string} = {}
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    local key, value = line:match("^(%a[%w_]*): (.*)$")
    if key then
      out[key] = value
    end
  end
  return out
end

--- Build an `item.Item` from its tree's parts: the parsed `meta` map,
--- whether a `held` marker blob was present, its `order` blob's
--- already-parsed ids, the ids named under the `edges/beats` and
--- `edges/blocked_by` kinds (with each blocked_by entry's reason blob
--- content), and every OTHER kind this reader found under `edges`,
--- carried opaquely. Content problems (a multiline title, a claimed
--- root, a malformed `target`, ...) are attached at `.decode_problems`
--- rather than failing the build — `item.decode`'s own tolerance,
--- reused here so a store built from a hand-edited commit still reads.
--- @param id string The item's id (the ref name's tail)
--- @param meta {string: string} `parse_meta`'s output
--- @param held boolean Whether a `held` marker blob was present
--- @param order {string} This item's ranked children, from its `order` blob
--- @param beats {string} Ids this item outranks
--- @param blocked_by {string} Ids this item waits on
--- @param block_reason {string: string} Blocker id -> reason
--- @param other_edges {string: {string: string}} Every edge kind this
--- reader does not interpret, kind -> id -> content
--- @return item.Item The item, present even with content problems
local function to_item(id: string, meta: {string: string}, held: boolean,
    order: {string}, beats: {string}, blocked_by: {string},
    block_reason: {string: string},
    other_edges: {string: {string: string}}): item.Item
  local repo, base, target_err = parse_target(meta.target or "")
  local it: item.Item = {
    id = id,
    title = meta.title or "",
    parent = meta.parent or "",
    repo = repo,
    base = base,
    key = meta.key or "",
    order = order,
    beats = beats,
    blocked_by = blocked_by,
    block_reason = block_reason,
    other_edges = other_edges,
    claim = meta.claim or "",
    builders = {},
    speccers = {},
    reviewer = meta.reviewer or "",
    pr = math.tointeger(tonumber(meta.pr or "0")) or 0,
    result = meta.result or "",
    verdict = meta.verdict or "",
    verdict_head = meta.verdict_head or "",
    verdict_spec = meta.verdict_spec or "",
    resolution = meta.resolution or "",
    is_held = held,
  }
  for name in (meta.builders or ""):gmatch("%S+") do
    it.builders[#it.builders + 1] = name
  end
  for name in (meta.speccers or ""):gmatch("%S+") do
    it.speccers[#it.speccers + 1] = name
  end
  local bad = item.problems(it)
  if target_err ~= "" then
    bad[#bad + 1] = target_err
  end
  if #bad > 0 then
    it.decode_problems = bad
  end
  return it
end

--- Build one `edges` subtree's worth of `<id> -> content` entries: an
--- empty marker for every `beats` id (`content_of` always "" there), a
--- reason blob for every `blocked_by` or other-kind id (`content_of`
--- the reason, "" writing the same empty marker). Empty when `ids` is
--- empty, so the caller never adds an entry for a kind with nothing in
--- it.
--- @param root string The repository root
--- @param ids {string} Ids under this kind
--- @param content_of function(id: string): string Each id's blob
--- content; "" writes the empty marker
--- @param empty_blob function(): string | nil, string The shared empty
--- blob sha, written at most once per tree
--- @param hash_object_fn function(root: string, content: string):
--- string | nil, string Either `gitobj.hash_object` (pure, the
--- default) or `gitobj.hash_object_write`, chosen once by `build_tree`
--- @return {gitobj.TreeEntry} The kind's own entries
--- @return string Error message
local function kind_entries(root: string, ids: {string},
    content_of: function(id: string): string,
    empty_blob: function(): string | nil, string,
    hash_object_fn: function(root: string, content: string): string | nil, string):
  {gitobj.TreeEntry} | nil, string
  local out: {gitobj.TreeEntry} = {}
  for _, id in ipairs(ids) do
    local content = content_of(id)
    local sha: string
    if (content or "") == "" then
      local eb, eerr = empty_blob()
      if eb == nil then
        return nil, eerr
      end
      sha = eb
    else
      local bsha, berr = hash_object_fn(root, content)
      if bsha == nil then
        return nil, berr
      end
      sha = bsha
    end
    out[#out + 1] = {mode = "100644", otype = "blob", sha = sha, name = id}
  end
  return out, ""
end

--- Build the `edges` subtree: one further subtree per non-empty kind —
--- `beats` (markers), `blocked_by` (reasons), and every kind in
--- `it.other_edges` (its own content per id) — omitted entirely (""
--- rather than the empty tree's sha) when nothing has any entries, so
--- an item with no edges at all carries no `edges` path.
--- @param root string The repository root
--- @param it item.Item The item
--- @param empty_blob function(): string | nil, string The shared empty
--- blob sha
--- @param hash_object_fn function(root: string, content: string):
--- string | nil, string Either `gitobj.hash_object` (pure, the
--- default) or `gitobj.hash_object_write`, chosen once by `build_tree`
--- @param mktree_fn function(root: string, entries: {gitobj.TreeEntry}):
--- string | nil, string Either `gitobj.mktree` (pure, the default) or
--- `gitobj.mktree_write`, chosen once by `build_tree`
--- @return string | nil The `edges` tree's sha, "" when it has nothing
--- @return string Error message
local function build_edges_tree(root: string, it: item.Item,
    empty_blob: function(): string | nil, string,
    hash_object_fn: function(root: string, content: string): string | nil, string,
    mktree_fn: function(root: string, entries: {gitobj.TreeEntry}): string | nil, string):
  string | nil, string
  local subtrees: {gitobj.TreeEntry} = {}
  local function add_kind(name: string, ids: {string},
      content_of?: function(id: string): string): string
    if #ids == 0 then
      return ""
    end
    local get_content = content_of
    if get_content == nil then
      get_content = function(_id: string): string
        return ""
      end
    end
    local entries, eerr = kind_entries(root, ids, get_content, empty_blob, hash_object_fn)
    if entries == nil then
      return eerr
    end
    local sha, terr = mktree_fn(root, entries)
    if sha == nil then
      return terr
    end
    subtrees[#subtrees + 1] = {mode = "40000", otype = "tree", sha = sha, name = name}
    return ""
  end
  local berr = add_kind("beats", it.beats or {}, nil)
  if berr ~= "" then
    return nil, berr
  end
  local blocked_ids: {string} = it.blocked_by or {}
  local blerr = add_kind("blocked_by", blocked_ids, function(id: string): string
      return (it.block_reason or {})[id] or ""
    end)
  if blerr ~= "" then
    return nil, blerr
  end
  local kinds: {string} = {}
  for kind in pairs(it.other_edges or {}) do
    kinds[#kinds + 1] = kind
  end
  table.sort(kinds)
  for _, kind in ipairs(kinds) do
    local idmap = (it.other_edges or {})[kind] or {}
    local ids: {string} = {}
    for id in pairs(idmap) do
      ids[#ids + 1] = id
    end
    table.sort(ids)
    local oerr = add_kind(kind, ids, function(id: string): string
        return idmap[id] or ""
      end)
    if oerr ~= "" then
      return nil, oerr
    end
  end
  if #subtrees == 0 then
    return "", ""
  end
  return mktree_fn(root, subtrees)
end

--- Build an item's git tree: `meta`, `spec.md` when given, `order`
--- when it has ranked at least one child, `held` when the item is
--- held, and `edges` when it carries any. `write` chooses
--- between the two forms every blob and subtree this needs goes
--- through: pure (the default — no process, nothing written, for a
--- caller only comparing the resulting sha against one it already
--- has, `_work.gitfsck`'s whole-board audit) or writing (a handful of
--- small objects actually landed in the odb, for a caller that
--- follows this with `commit_tree` against the sha it gets back).
--- @param root string The repository root
--- @param it item.Item The item
--- @param spec_body string | nil The spec sidecar; nil or "" omits `spec.md`
--- @param write boolean | nil True to actually write the objects;
--- false or nil computes the id only
--- @return string | nil The item's tree sha
--- @return string Error message
local function build_tree(root: string, it: item.Item,
    spec_body: string | nil, write?: boolean): string | nil, string
  local hash_object_fn = gitobj.hash_object
  local mktree_fn = gitobj.mktree
  if write then
    hash_object_fn = gitobj.hash_object_write
    mktree_fn = gitobj.mktree_write
  end
  local entries: {gitobj.TreeEntry} = {}
  local meta_sha, merr = hash_object_fn(root, encode_meta(it))
  if meta_sha == nil then
    return nil, merr
  end
  entries[#entries + 1] = {mode = "100644", otype = "blob", sha = meta_sha, name = "meta"}
  if (spec_body or "") ~= "" then
    local spec_sha, serr = hash_object_fn(root, spec_body)
    if spec_sha == nil then
      return nil, serr
    end
    entries[#entries + 1] =
    {mode = "100644", otype = "blob", sha = spec_sha, name = "spec.md"}
  end
  if #(it.order or {}) > 0 then
    local order_sha, oerr = hash_object_fn(root, encode_order(it.order))
    if order_sha == nil then
      return nil, oerr
    end
    entries[#entries + 1] =
    {mode = "100644", otype = "blob", sha = order_sha, name = "order"}
  end
  -- The empty blob every marker (a `beats` entry, a reason-less
  -- `blocked_by`/other entry, the `held` marker itself) points at has
  -- to actually exist in THIS repository's object database before a
  -- WRITING `mktree_fn` will link to it — `git hash-object -w` on ""
  -- always resolves to the same well-known sha, so writing it here is
  -- idempotent and cheap, and it is written at most once per tree even
  -- when several entries need it. The pure form just recomputes that
  -- same well-known sha, equally cheaply.
  local empty_sha: string = nil
  local function empty_blob(): string | nil, string
    if empty_sha == nil then
      local sha, eerr = hash_object_fn(root, "")
      if sha == nil then
        return nil, eerr
      end
      empty_sha = sha
    end
    return empty_sha, ""
  end
  if it.is_held then
    local eb, eerr = empty_blob()
    if eb == nil then
      return nil, eerr
    end
    entries[#entries + 1] = {mode = "100644", otype = "blob", sha = eb, name = "held"}
  end
  local edges_sha, eerr2 = build_edges_tree(root, it, empty_blob, hash_object_fn, mktree_fn)
  if edges_sha == nil then
    return nil, eerr2
  end
  if edges_sha ~= "" then
    entries[#entries + 1] = {mode = "40000", otype = "tree", sha = edges_sha, name = "edges"}
  end
  return mktree_fn(root, entries)
end

local record itemtree
  META_KEYS: {string}
  format_target: function(repo: string, base: string): string
  parse_target: function(target: string): string, string, string
  encode_meta: function(it: item.Item): string
  parse_meta: function(text: string): {string: string}
  encode_order: function(ids: {string}): string
  parse_order: function(text: string): {string}
  to_item: function(id: string, meta: {string: string}, held: boolean,
  order: {string}, beats: {string}, blocked_by: {string},
  block_reason: {string: string},
  other_edges: {string: {string: string}}): item.Item
  build_tree: function(root: string, it: item.Item,
  spec_body: string | nil, write?: boolean): string | nil, string
end

local M: itemtree = {
  META_KEYS = META_KEYS,
  format_target = format_target,
  parse_target = parse_target,
  encode_meta = encode_meta,
  parse_meta = parse_meta,
  encode_order = encode_order,
  parse_order = parse_order,
  to_item = to_item,
  build_tree = build_tree,
}

return M
