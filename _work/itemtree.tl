--- An item's canonical git tree: the `meta` text blob, the optional
--- `spec.md` sidecar, and the `beats`/`blocked_by` subtrees — and the
--- two directions between that tree and an `_work.item.Item`. This is
--- the ONE place that shape is written, so `_work.store`'s writer and
--- reader, and the round-trip test, all agree on it by construction.
---
--- `meta` carries every scalar field as one `key: value` line, keys in
--- the order `_work.item.Item` declares them (minus `id`, `beats` and
--- `blocked_by`, which live outside `meta` entirely); a zero value —
--- "", 0, false, an empty list — is OMITTED, so two items differing
--- only in which fields are unset differ in their tree too. `beats`
--- and `blocked_by` are subtrees rather than more `meta` lines because
--- each entry is itself content: an empty marker blob for a beaten
--- id, a reason blob for a blocker. Git sorts a tree's own entries by
--- name, so decoding one back loses whatever ORDER the fields were
--- written in — immaterial here, since every reader of `beats` or
--- `blocked_by` treats it as a set, never a sequence.
local gitobj = require("_work.gitobj")
local item = require("_work.item")

--- Scalar meta keys, in the order they are written — `_work.item.Item`'s
--- own declared order, minus `id`, `beats`, `blocked_by` and
--- `block_reason`, which are not `meta` lines.
local META_KEYS < const >: {string} = {
  "title", "parent", "repo", "base", "lane", "claim", "reviewer", "pr",
  "result", "verdict", "verdict_head", "verdict_spec", "resolution",
  "held", "builders", "speccers",
}

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
  put("repo", it.repo or "")
  put("base", it.base or "")
  put("lane", it.lane or "")
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
  if it.is_held then
    parts[#parts + 1] = "held: true\n"
  end
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
--- the ids named under `beats`, and the ids named under `blocked_by`
--- with each one's reason blob content. Content problems (a multiline
--- title, a claimed root, ...) are attached at `.decode_problems`
--- rather than failing the build — `item.decode`'s own tolerance,
--- reused here so a store built from a hand-edited commit still reads.
--- @param id string The item's id (the ref name's tail)
--- @param meta {string: string} `parse_meta`'s output
--- @param beats {string} Ids this item outranks
--- @param blocked_by {string} Ids this item waits on
--- @param block_reason {string: string} Blocker id -> reason
--- @return item.Item The item, present even with content problems
local function to_item(id: string, meta: {string: string}, beats: {string},
    blocked_by: {string}, block_reason: {string: string}): item.Item
  local it: item.Item = {
    id = id,
    title = meta.title or "",
    parent = meta.parent or "",
    repo = meta.repo or "",
    base = meta.base or "",
    lane = meta.lane or "",
    beats = beats,
    blocked_by = blocked_by,
    block_reason = block_reason,
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
    is_held = meta.held == "true",
  }
  for name in (meta.builders or ""):gmatch("%S+") do
    it.builders[#it.builders + 1] = name
  end
  for name in (meta.speccers or ""):gmatch("%S+") do
    it.speccers[#it.speccers + 1] = name
  end
  local bad = item.problems(it)
  if #bad > 0 then
    it.decode_problems = bad
  end
  return it
end

--- Build an item's git tree: `meta`, `spec.md` when given, and the
--- `beats`/`blocked_by` subtrees when either has entries. Every blob
--- and subtree this needs is written first — a handful of small
--- objects, at most — then the root tree is built from whichever
--- entries actually apply.
--- @param root string The repository root
--- @param it item.Item The item
--- @param spec_body string | nil The spec sidecar; nil or "" omits `spec.md`
--- @return string | nil The item's tree sha
--- @return string Error message
local function build_tree(root: string, it: item.Item,
    spec_body: string | nil): string | nil, string
  local entries: {gitobj.TreeEntry} = {}
  local meta_sha, merr = gitobj.hash_object(root, encode_meta(it))
  if meta_sha == nil then
    return nil, merr
  end
  entries[#entries + 1] = {mode = "100644", otype = "blob", sha = meta_sha, name = "meta"}
  if (spec_body or "") ~= "" then
    local spec_sha, serr = gitobj.hash_object(root, spec_body)
    if spec_sha == nil then
      return nil, serr
    end
    entries[#entries + 1] =
    {mode = "100644", otype = "blob", sha = spec_sha, name = "spec.md"}
  end
  -- The empty blob every `beats` marker (and every reason-less
  -- `blocked_by` entry) points at has to actually exist in THIS
  -- repository's object database before `mktree` will link to it —
  -- `git hash-object -w` on "" always resolves to the same well-known
  -- sha, so writing it here is idempotent and cheap, and it is
  -- written at most once per tree even when several entries need it.
  local empty_sha: string = nil
  local function empty_blob(): string | nil, string
    if empty_sha == nil then
      local sha, eerr = gitobj.hash_object(root, "")
      if sha == nil then
        return nil, eerr
      end
      empty_sha = sha
    end
    return empty_sha, ""
  end
  if #(it.beats or {}) > 0 then
    local eb, eerr = empty_blob()
    if eb == nil then
      return nil, eerr
    end
    local beat_entries: {gitobj.TreeEntry} = {}
    for _, b in ipairs(it.beats) do
      beat_entries[#beat_entries + 1] = {mode = "100644", otype = "blob", sha = eb, name = b}
    end
    local beats_sha, berr = gitobj.mktree(root, beat_entries)
    if beats_sha == nil then
      return nil, berr
    end
    entries[#entries + 1] = {mode = "40000", otype = "tree", sha = beats_sha, name = "beats"}
  end
  if #(it.blocked_by or {}) > 0 then
    local blocker_entries: {gitobj.TreeEntry} = {}
    for _, b in ipairs(it.blocked_by) do
      local reason = (it.block_reason or {})[b] or ""
      local reason_sha: string
      if reason == "" then
        local eb, eerr = empty_blob()
        if eb == nil then
          return nil, eerr
        end
        reason_sha = eb
      else
        local rsha, rerr = gitobj.hash_object(root, reason)
        if rsha == nil then
          return nil, rerr
        end
        reason_sha = rsha
      end
      blocker_entries[#blocker_entries + 1] =
      {mode = "100644", otype = "blob", sha = reason_sha, name = b}
    end
    local blocked_sha, blerr = gitobj.mktree(root, blocker_entries)
    if blocked_sha == nil then
      return nil, blerr
    end
    entries[#entries + 1] =
    {mode = "40000", otype = "tree", sha = blocked_sha, name = "blocked_by"}
  end
  return gitobj.mktree(root, entries)
end

local record itemtree
  META_KEYS: {string}
  encode_meta: function(it: item.Item): string
  parse_meta: function(text: string): {string: string}
  to_item: function(id: string, meta: {string: string}, beats: {string},
  blocked_by: {string}, block_reason: {string: string}): item.Item
  build_tree: function(root: string, it: item.Item,
  spec_body: string | nil): string | nil, string
end

local M: itemtree = {
  META_KEYS = META_KEYS,
  encode_meta = encode_meta,
  parse_meta = parse_meta,
  to_item = to_item,
  build_tree = build_tree,
}

return M
