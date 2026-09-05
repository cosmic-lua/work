--- A legible, derived display for a board item's id — never stored,
--- computed fresh on every render and every input.
---
--- Same-week KSUIDs share their LEADING characters (creation order is
--- lexicographic order), so the last 8 characters are what actually
--- distinguishes one item from its neighbors — and they are pure
--- entropy, and a literal substring of the id, so the rendered handle
--- greps branch logs and PR bodies directly. Measured against the
--- live board (`git for-each-ref --format='%(refname)' refs/heads/items
--- refs/heads/ended`), `id:sub(20)` is collision-free across every item,
--- exact and case-folded.
local refs = require("_work.refs")

--- An item's tail as two underscore-divided 4-char chunks, undecorated
--- — what a machine-facing string embeds (a branch name, a minted
--- session label); `handle` wraps this for a human-facing display.
--- The divider is an underscore rather than a hyphen because `_` is a
--- word character and `-` is not: a double-click selects the whole
--- 9-character body in one gesture, and a hyphen stays free as a
--- field separator in a string this is only ONE part of.
--- @param id string A full item id (a 27-char KSUID)
--- @return string "XXXX_XXXX"
local function bare(id: string): string
  local t = id:sub(20)
  return t:sub(1, 4) .. "_" .. t:sub(5, 8)
end

--- `bare`, wrapped in guillemets so a reader can tell a handle from a
--- word, a count, or the `[full id]` bracket on sight.
--- @param id string A full item id (a 27-char KSUID)
--- @return string "«XXXX_XXXX»"
local function handle(id: string): string
  return "«" .. bare(id) .. "»"
end

--- Whether input has a tail's shape: 8 base62 characters, with at
--- most one divider (`_` or `-`), which — when present — sits right
--- after the 4th character, optionally wrapped in the guillemets a
--- rendered handle carries. Both dividers are accepted so a
--- hyphenated handle from scrollback still parses — only rendering
--- has settled on the underscore. So a caller can tell a tail
--- attempt from an id prefix before asking `resolve_glob` to search.
--- @param input string Candidate input
--- @return boolean True when it has tail shape
local function is_tail_shape(input: string): boolean
  return input:match("^%w%w%w%w[%-_]?%w%w%w%w$") ~= nil
  or input:match("^«%w%w%w%w[%-_]?%w%w%w%w»$") ~= nil
end

--- `input` reduced to its bare 8 characters: guillemets and either
--- divider stripped, case preserved. What an EXACT match compares
--- against — the glob patterns `glob_patterns` builds; a caller after
--- a case-insensitive match folds the result itself.
--- @param input string What a session typed
--- @return string The normalized tail
local function normalize(input: string): string
  return (input:gsub("[«»%-_]", ""))
end

--- Every id in `ids`, sorted into id order (creation order — same-week
--- KSUIDs share their leading characters, so a lexicographic sort on
--- the full id is a chronological one) and rendered as its own
--- `handle` — the form a session typed and the board prints, never a
--- bare tail or a raw id — then space-joined. What an ambiguous
--- match's refusal lists; shared by every resolver (`resolve_glob`
--- here, `_work.cachequery.resolve_tail`) so a collision refuses with
--- the same rendering regardless of which one answered it.
--- @param ids {string} The ambiguous candidates' ids, any order
--- @return string Space-joined handles, in id order
local function join_handles(ids: {string}): string
  local sorted: {string} = {}
  for i, id in ipairs(ids) do
    sorted[i] = id
  end
  table.sort(sorted)
  local handles: {string} = {}
  for i, id in ipairs(sorted) do
    handles[i] = handle(id)
  end
  return table.concat(handles, " ")
end

--- The `for-each-ref` glob patterns an exact tail match needs: the
--- normalized tail suffixed onto a `*` in each namespace.
--- `for-each-ref` patterns are fnmatch, so this is one process and no
--- content read — the same shape and cost as `_work.store.resolve`'s
--- own prefix glob.
--- @param input string What a session typed
--- @return {string} The two glob patterns
local function glob_patterns(input: string): {string}
  local t = normalize(input)
  return {"refs/heads/items/*" .. t, "refs/heads/ended/*" .. t}
end

--- `found`, collapsed to distinct item ids the same way
--- `_work.store.resolve` does: an id filed under both
--- `refs/heads/items` and `refs/heads/ended` at once (the legacy
--- duplicate case `_work.gitread` picks a winner for at load time)
--- counts once towards ambiguity here. `ref`/`sha` come back set only
--- when `found` itself has exactly one entry — a genuine duplicate
--- leaves them "", so the load that follows runs
--- `_work.gitread.load_item`'s own duplicate-picking logic instead of
--- an arbitrarily chosen half.
--- @param found {refs.RefEntry} What one `for-each-ref` call returned
--- @return {string} Distinct ids, in `found`'s own order
--- @return string ref, "" unless `found` has exactly one entry
--- @return string sha, "" unless `found` has exactly one entry
local function distinct_ids(found: {refs.RefEntry}): {string}, string, string
  local ids: {string} = {}
  local seen: {string: boolean} = {}
  for _, r in ipairs(found) do
    local id = r.refname:match("/([^/]+)$")
    if id ~= nil and not seen[id] then
      seen[id] = true
      ids[#ids + 1] = id
    end
  end
  local ref, sha = "", ""
  if #found == 1 then
    ref, sha = found[1].refname, found[1].sha
  end
  return ids, ref, sha
end

--- What `resolve_glob` resolves a tail to: the id, plus `ref`/`sha`
--- when the match came with a one-shot lease to give `load` — "" for
--- both when it did not (a genuine `items/`+`ended/` duplicate; see
--- `distinct_ids`).
local record Resolved
  id: string
  ref: string
  sha: string
end

--- Resolve a tail against the ref layout directly — no whole-board
--- load. An exact glob first (`glob_patterns`, one process); only when
--- that matches nothing AND the tail carries a letter (case folding
--- cannot change a match on an all-digit tail, which the exact glob
--- already covers) does a case-folded fallback follow: one more
--- `for-each-ref`, over the two whole namespaces, matched in Lua
--- against every ref's own tail. Either stage's `ref`/`sha` (from
--- `distinct_ids`) are the one-shot lease
--- `_work.store.load_item` spends next, same as
--- `_work.store.resolve`'s own prefix match.
--- @param root string The repository root
--- @param input string What a session typed
--- @return Resolved | nil The resolved id, with a lease when one applies
--- @return string Error message
local function resolve_glob(root: string, input: string): Resolved | nil, string
  local found, ferr = refs.for_each_ref(root, glob_patterns(input))
  if found == nil then
    return nil, ferr
  end
  local ids, ref, sha = distinct_ids(found)
  if #ids == 1 then
    return {id = ids[1], ref = ref, sha = sha}
  end
  if #ids > 1 then
    return nil, ("%s is ambiguous: %s"):format(input, join_handles(ids))
  end
  local t = normalize(input)
  if t:match("%a") == nil then
    return nil, ("no item matches tail %s"):format(input)
  end
  local all_found, aerr = refs.for_each_ref(root,
    {"refs/heads/items/*", "refs/heads/ended/*"})
  if all_found == nil then
    return nil, aerr
  end
  local folded = t:lower()
  local ci_found: {refs.RefEntry} = {}
  local ci_ids: {string} = {}
  local seen: {string: boolean} = {}
  for _, r in ipairs(all_found) do
    local id = r.refname:match("/([^/]+)$")
    if id ~= nil and id:sub(20):lower() == folded and not seen[id] then
      seen[id] = true
      ci_ids[#ci_ids + 1] = id
      ci_found[#ci_found + 1] = r
    end
  end
  if #ci_ids == 0 then
    return nil, ("no item matches tail %s"):format(input)
  end
  if #ci_ids > 1 then
    return nil, ("%s is ambiguous: %s"):format(input, join_handles(ci_ids))
  end
  local _, cref, csha = distinct_ids(ci_found)
  return {id = ci_ids[1], ref = cref, sha = csha}
end

local record tail
  bare: function(id: string): string
  handle: function(id: string): string
  is_tail_shape: function(input: string): boolean
  normalize: function(input: string): string
  join_handles: function(ids: {string}): string
  glob_patterns: function(input: string): {string}
  type Resolved = Resolved
  resolve_glob: function(root: string, input: string): Resolved | nil, string
end

local M: tail = {
  bare = bare,
  handle = handle,
  is_tail_shape = is_tail_shape,
  normalize = normalize,
  join_handles = join_handles,
  glob_patterns = glob_patterns,
  resolve_glob = resolve_glob,
}

return M
