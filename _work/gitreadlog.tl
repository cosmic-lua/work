--- An item's own commit history, read from its ref. Beside
--- `_work.gitread.read_spec` in role — the same store read layer, the
--- same tolerant "" for what a ref does not carry — and split into its
--- own file purely to keep `_work.gitread` under the repo's line cap,
--- exactly as `_work.gitreadmany` is.
---
--- What a commit's tree carries is the item's CURRENT state; what its
--- message carries is the retrospective — what was measured, what was
--- found, what happened along the way. Nothing else in the store reads
--- a commit message, so this is the one place that grammar lives.
local child = require("cosmic.child")
local refs = require("_work.refs")

--- The field and record separators the `git log` format below puts
--- between values and between commits. ASCII unit and record
--- separators: a commit subject or body is text, so neither appears in
--- one, while every other candidate (a tab, a newline) does.
local US < const > = "\31"
local RS < const > = "\30"

--- One commit's fields, in the order the format below prints them.
--- `%S` (the ref each commit was reached from) rides ahead of them in
--- the batched form only, so the two forms share this one format.
local FIELDS < const > =
"%H" .. US .. "%ct" .. US .. "%an <%ae>" .. US .. "%s" .. US .. "%b"

--- The trailer keys gitboard itself writes into a commit message —
--- `Op:` on every commit (`_work.gitobj`, `_work.fastimport`) and
--- `Claim-Batch:` on a claim bridge (`_work.gitclaim`). They are the
--- tool's own bookkeeping, not prose anybody wrote, so `prose_of`
--- below drops the trailing paragraphs made only of them: what is left
--- is the body an author actually put there, empty for every commit
--- the board carries today.
local TOOL_TRAILERS < const >: {string: boolean} = {
  ["Op"] = true, ["Claim-Batch"] = true,
}

--- One commit on an item's ref.
local record Entry
  --- The full commit id. A renderer abbreviates it; the store never
  --- does, so a caller comparing against a recorded head compares
  --- whole ids.
  sha: string
  --- Committer date, seconds since the epoch (git's `%ct`) — the raw
  --- number, formatted by whoever renders it, the same division
  --- `_work.publish.history` makes for the same reason: `%cI`'s own
  --- suffix is a fact of the git binary installed.
  at: integer
  --- The commit's author as `name <email>` — the session that made
  --- the mutation, which `_work.gitgate` threads through as the
  --- author while `gitboard` itself stays the committer.
  author: string
  --- The commit subject: the verb grammar every mutation writes
  --- (`new <id>`, `spec <id>`, `take <id> by <session>`, ...).
  subject: string
  --- The message body with gitboard's own trailers removed, "" when
  --- the commit carries nothing but them.
  body: string
end

--- Split `text` on `sep`, keeping empty pieces.
--- @param text string The text to split
--- @param sep string A one-character separator
--- @return {string} The pieces, at least one
local function split(text: string, sep: string): {string}
  local out: {string} = {}
  local from = 1
  while true do
    local at = text:find(sep, from, true)
    if at == nil then
      out[#out + 1] = text:sub(from)
      return out
    end
    out[#out + 1] = text:sub(from, at - 1)
    from = at + 1
  end
end

--- A commit body with gitboard's own trailer paragraphs removed: the
--- prose an author wrote, "" when the body is nothing but trailers.
--- Repeated, because a claim bridge carries two such paragraphs
--- (`Claim-Batch:` then `Op:`) and git counts only the last as
--- trailers; only paragraphs made ENTIRELY of `TOOL_TRAILERS` keys are
--- dropped, so a prose paragraph that happens to open with a
--- colon-terminated word survives.
--- @param body string The raw `%b` body
--- @return string The prose, possibly empty
local function prose_of(body: string): string
  local lines = split((body:gsub("%s+$", "")), "\n")
  while #lines > 0 do
    local start = #lines + 1
    for i = #lines, 1, -1 do
      if lines[i]:match("^%s*$") ~= nil then
        break
      end
      start = i
    end
    if start > #lines then
      return ""
    end
    for i = start, #lines do
      local key = lines[i]:match("^([%w][%w%-]*):%s")
      if key == nil or not TOOL_TRAILERS[key] then
        return table.concat(lines, "\n", 1, #lines)
      end
    end
    local keep = start - 1
    while keep > 0 and lines[keep]:match("^%s*$") ~= nil do
      keep = keep - 1
    end
    local kept: {string} = {}
    for i = 1, keep do
      kept[#kept + 1] = lines[i]
    end
    lines = kept
  end
  return ""
end

--- One record's fields into an `Entry`, nil for a chunk that is not
--- one (the empty piece before the first separator, a truncated tail).
--- @param chunk string One record, separators still inside it
--- @param offset integer How many leading fields to skip (1 for the
--- batched form's own `%S`)
--- @return Entry | nil The entry
local function entry_of(chunk: string, offset: integer): Entry | nil
  local parts = split(chunk, US)
  if #parts < offset + 5 then
    return nil
  end
  local at = math.tointeger(tonumber(parts[offset + 2]))
  if at == nil then
    return nil
  end
  -- `%b` is last in the format, so a body carrying a unit separator of
  -- its own rejoins here rather than truncating the entry.
  local body = table.concat(parts, US, offset + 5, #parts)
  return {sha = parts[offset + 1], at = at, author = parts[offset + 3],
    subject = parts[offset + 4], body = prose_of(body)}
end

--- Every entry in `text`, in the order git printed them.
--- @param text string One `git log` run's stdout
--- @param offset integer How many leading fields to skip per record
--- @return {Entry} The entries, possibly empty
local function entries_of(text: string, offset: integer): {Entry}
  local out: {Entry} = {}
  for _, chunk in ipairs(split(text, RS)) do
    local e = entry_of(chunk, offset)
    if e ~= nil then
      out[#out + 1] = e
    end
  end
  return out
end

--- One item's history, OLDEST FIRST, tried against every candidate ref
--- in order — the same candidate list `_work.gitread.read_spec` takes,
--- and the same mapping of a `refs/heads/*` name through the
--- configured board mode before dereferencing it. One `git log` per
--- call; a raw object id passes through unchanged.
--- @param root string The repository root
--- @param candidates {string} Ref names or object ids to try, in order
--- @return {Entry} | nil The entries, oldest first
--- @return string Error message; set only when no candidate could be read
local function read_history(root: string, candidates: {string}): {Entry} | nil, string
  for _, ref in ipairs(candidates) do
    local object = ref
    if ref:match("^refs/heads/") ~= nil then
      local canonical = refs.canonical_ref(root, ref)
      if canonical ~= nil then
        object = canonical
      end
    end
    local r = child.run({"git", "log", "--reverse", "--format=" .. RS .. FIELDS,
        object}, {cwd = root})
    if r ~= nil and r.ok then
      return entries_of(r.stdout, 0)
    end
  end
  return nil, ("no history for %s"):format(table.concat(candidates, " "))
end

--- Every named item's history in ONE `git log`, oldest first per item,
--- empty for an id whose tip is unknown — the whole-board counterpart
--- to `read_history`, so a board-wide pass over entries costs one
--- process instead of one per item, the same way
--- `_work.gitread.read_specs` costs one `cat-file --batch` instead of
--- one `cat-file -p` per spec. Reads against the tip SHAS rather than
--- ref names, for the same reason `read_specs` does: an object id is
--- unambiguous in either board mode. `--source` makes git name the
--- argument each commit was reached from, which is how one merged walk
--- still attributes every commit to its own item.
--- @param root string The repository root
--- @param shas_by_id {string: string} Each item's tip sha, from `list`
--- @param ids {string} Item ids to read, in any order
--- @return {string: {Entry}} | nil Entries by id, oldest first
--- @return string Error message
local function read_histories(root: string, shas_by_id: {string: string},
    ids: {string}): {string: {Entry}} | nil, string
  local result: {string: {Entry}} = {}
  local argv: {string} = {"git", "log", "--reverse", "--source",
    "--format=" .. RS .. "%S" .. US .. FIELDS}
  local base = #argv
  local id_of: {string: string} = {}
  for _, id in ipairs(ids) do
    result[id] = {}
    local sha = shas_by_id[id]
    if sha ~= nil then
      id_of[sha] = id
      argv[#argv + 1] = sha
    end
  end
  if #argv == base then
    return result
  end
  local r, err = child.run(argv, {cwd = root})
  if r == nil then
    return nil, err
  end
  if not r.ok then
    return nil, ("git log failed: %s"):format(r.stderr)
  end
  for _, chunk in ipairs(split(r.stdout, RS)) do
    local source = chunk:match("^([^" .. US .. "]*)")
    local id = id_of[source or ""]
    if id ~= nil then
      local e = entry_of(chunk, 1)
      if e ~= nil then
        local own = result[id]
        own[#own + 1] = e
      end
    end
  end
  return result
end

--- The item's OUTCOME body: what the mutation that ended the item
--- recorded, or what its latest handover recorded while it is still
--- open. A resolution rides a `done <id> ...` commit; a handover rides
--- the `take <id> by <session> head:...`/`result:...` commit, which is
--- what distinguishes it from the bare `take <id> by <session>` a
--- claim writes. "" when no such commit carries prose — every commit
--- the board carries today.
--- @param entries {Entry} One item's history, oldest first
--- @param resolved boolean Whether the item carries a resolution
--- @return string The outcome prose, possibly empty
local function outcome_body(entries: {Entry}, resolved: boolean): string
  for i = #entries, 1, -1 do
    local e = entries[i]
    local is_outcome: boolean
    if resolved then
      is_outcome = e.subject:match("^done ") ~= nil
    else
      is_outcome = e.subject:match("^take ") ~= nil
      and (e.subject:match(" head:") ~= nil or e.subject:match(" result:") ~= nil)
    end
    if is_outcome then
      return e.body
    end
  end
  return ""
end

local record gitreadlog
  type Entry = Entry
  prose_of: function(body: string): string
  read_history: function(root: string, candidates: {string}): {Entry} | nil, string
  read_histories: function(root: string, shas_by_id: {string: string},
  ids: {string}): {string: {Entry}} | nil, string
  outcome_body: function(entries: {Entry}, resolved: boolean): string
end

local M: gitreadlog = {
  prose_of = prose_of,
  read_history = read_history,
  read_histories = read_histories,
  outcome_body = outcome_body,
}

return M
