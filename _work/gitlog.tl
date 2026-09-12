--- The `log ID` verb: one item's own commit history, newest first.
--- Every retrospective fact an item carries — what was measured, what
--- was found, what happened along the way — lives in the message
--- bodies on its ref, and this is the verb that shows them; the item's
--- tree carries only its current state, which `show ID` renders.
---
--- Like every read verb, the report is PURE over already-read state
--- and the `cmd_` half owns the store reads: what a session reads is
--- the contract, and a report that returns its lines can be asserted
--- on without capturing stdout.
local gate = require("_work.gitgate")
local gitreadlog = require("_work.gitreadlog")
local store = require("_work.store")
local tail = require("_work.tail")

local type Entry = gitreadlog.Entry

local verdict_line = gate.verdict_line

--- How far a body line is indented under its own subject line: enough
--- that a wrapped prose paragraph never reads as another entry.
local INDENT < const > = "    "

--- One entry's own heading: when it happened, who made it, and what it
--- was. UTC `Z`-form, the same timestamp shape `show ID`'s `opened:`
--- line and its history block already print, rendered here rather than
--- by git so it never depends on the host's git version or its `TZ`.
--- @param e Entry One commit
--- @return string The heading line
local function heading(e: Entry): string
  local at = os.date("!%Y-%m-%dT%H:%M:%SZ", e.at) as string -- cast: os.date with a format string always returns string
  return ("%s %s %s"):format(at, e.author, e.subject)
end

--- The lines `log ID` prints: one heading per entry, NEWEST FIRST,
--- each followed by its own body indented. An entry whose body is
--- empty prints its heading alone. `oneline` keeps the headings and
--- drops every body, so a long history reads as one line per mutation.
--- @param entries {Entry} One item's history, oldest first
--- @param oneline boolean Headings only, no bodies
--- @return {string} The lines to print
local function log_report(entries: {Entry}, oneline?: boolean): {string}
  local out: {string} = {}
  for i = #entries, 1, -1 do
    local e = entries[i]
    out[#out + 1] = heading(e)
    if not oneline and e.body ~= "" then
      for line in (e.body .. "\n"):gmatch("([^\n]*)\n") do
        out[#out + 1] = line == "" and "" or (INDENT .. line)
      end
    end
  end
  return out
end

--- Print one item's history.
--- @param s store.Store The store
--- @param id string The item id, already resolved by the dispatcher
--- @param oneline boolean Subjects only, no bodies
--- @return integer Exit code
local function cmd_log(s: store.Store, id: string, oneline?: boolean): integer
  -- `store.load` first: it proves the id names a real ref and leaves
  -- the lease behind, so the history read below dereferences the one
  -- ref this item actually lives on rather than trying both
  -- namespaces.
  local it, lerr = store.load(s, id)
  if it == nil then
    return verdict_line("log", false, lerr)
  end
  local ref = s.leased_ref[id]
  local candidates: {string} = {"refs/heads/items/" .. id,
    "refs/heads/ended/" .. id}
  if ref ~= nil then
    candidates = {ref}
  end
  local entries, herr = gitreadlog.read_history(s.root, candidates)
  if entries == nil then
    return verdict_line("log", false, herr)
  end
  for _, line in ipairs(log_report(entries, oneline)) do
    print(line)
  end
  return verdict_line("log", true,
    ("%s carries %d %s"):format(tail.handle(id), #entries,
      #entries == 1 and "entry" or "entries"))
end

local record gitlog
  heading: function(e: Entry): string
  log_report: function(entries: {Entry}, oneline?: boolean): {string}
  cmd_log: function(s: store.Store, id: string, oneline?: boolean): integer
end

local M: gitlog = {
  heading = heading,
  log_report = log_report,
  cmd_log = cmd_log,
}

return M
