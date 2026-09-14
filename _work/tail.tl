--- A legible, derived display for a board item's id — never stored,
--- computed fresh on every render and every input.
---
--- Same-week KSUIDs share their LEADING characters (creation order is
--- lexicographic order), so the last 8 characters are what actually
--- distinguishes one item from its neighbors — and they are pure
--- entropy, and a literal substring of the id, so the rendered handle
--- greps branch logs and PR bodies directly.
local item = require("_work.item")
local child = require("cosmic.child")
local format = require("_work.format")

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

--- The id and title every rendered item line leads with: the id's
--- tail — the last 8 characters, pure entropy and a literal
--- substring of the id — chunked for legibility.
--- @param it item.Item The item
--- @return string "tail-chunked title"
local function id_line(it: item.Item): string
  return ("%s %s"):format(handle(it.id), it.title)
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
--- against; a caller after
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

--- Resolve an exact tail first, then a case-folded tail, against native ids.
local function resolve_ids(ids: {string}, input: string): string | nil, string
  local wanted = normalize(input)
  local exact: {string} = {}
  local folded: {string} = {}
  for _, id in ipairs(ids) do
    if id:sub(-8) == wanted then exact[#exact + 1] = id end
    if id:sub(-8):lower() == wanted:lower() then folded[#folded + 1] = id end
  end
  local matches = #exact > 0 and exact or folded
  if #matches == 1 then return matches[1], "" end
  if #matches == 0 then return nil, "no item matches tail " .. input end
  return nil, input .. " is ambiguous: " .. join_handles(matches)
end

local record Resolved
  id: string
  ref: string
  sha: string
end

--- Resolve a native tree path without loading metadata or consulting archived refs.
--- CLI callers use resolve_ids with their invocation's already-decoded view.
local function resolve_glob(root: string, input: string): Resolved | nil, string
  local head, err = format.state_head(root)
  if head == nil then return nil, err end
  local tree, terr = child.run({"git", "ls-tree", "--name-only", head .. ":items"}, {cwd = root})
  if tree == nil then return nil, terr end
  if not tree.ok then return nil, tree.stderr end
  local ids: {string} = {}
  for id in tree.stdout:gmatch("[^\n]+") do ids[#ids + 1] = id end
  local id, ierr = resolve_ids(ids, input)
  if id == nil then return nil, ierr end
  local history, herr = child.run({"git", "log", "-1", "--first-parent", "--format=%H",
      head, "--", "items/" .. id, "claims/" .. id}, {cwd = root})
  if history == nil then return nil, herr end
  if not history.ok then return nil, history.stderr end
  return {id = id, ref = "refs/heads/state", sha = history.stdout:gsub("%s+$", "")}, ""
end

local record tail
  bare: function(id: string): string
  handle: function(id: string): string
  id_line: function(it: item.Item): string
  is_tail_shape: function(input: string): boolean
  normalize: function(input: string): string
  join_handles: function(ids: {string}): string
  resolve_ids: function(ids: {string}, input: string): string | nil, string
  type Resolved = Resolved
  resolve_glob: function(root: string, input: string): Resolved | nil, string
end

local M: tail = {
  bare = bare,
  handle = handle,
  id_line = id_line,
  is_tail_shape = is_tail_shape,
  normalize = normalize,
  join_handles = join_handles,
  resolve_ids = resolve_ids,
  resolve_glob = resolve_glob,
}

return M
