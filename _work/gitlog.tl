--- The `log ID` verb: one item's own commit history, newest first,
--- and `log ID --add FILE`, the one way to put something INTO it.
--- Retrospective prose lives in immutable item log blobs. Native
--- first-parent events attribute each entry to its item and author.
---
--- The read half is PURE over already-read state, like every read
--- verb, and its `cmd_` half owns the store reads: what a session
--- reads is the contract, and a report that returns its lines can be
--- asserted on without capturing stdout.
---
--- Append adds one log path without changing metadata. It observes
--- the whole item and claim authority before native publication.
local claimgate = require("_work.gitclaimgate")
local format = require("_work.format")
local fs = require("cosmic.fs")
local gate = require("_work.gitgate")
local gitreadlog = require("_work.gitreadlog")
local publish = require("_work.publish")
local refs = require("_work.refs")
local store = require("_work.store")
local storeinit = require("_work.storeinit")
local statewrite = require("_work.statewrite")
local tail = require("_work.tail")

local type Entry = gitreadlog.Entry

local verdict_line = gate.verdict_line

--- How far a body line is indented under its own subject line: enough
--- that a wrapped prose paragraph never reads as another entry.
local INDENT < const > = "    "

--- The tool's own git identity: the committer on an entry's commit,
--- and its author too when no session named itself — the same pair
--- `_work.gitwrite` stamps on every item commit, and `_work.format`
--- and `_work.storeinit` on the board refs they write.

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
  local entries, herr = gitreadlog.read_state_history(s.root, s.state_head, id)
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

--- One entry's commit subject: the verb, the item's id as every other
--- subject abbreviates it, and the session that observed it — `note
--- <id8> by <session>`, the same clause `take <id8> by <session>`
--- already writes, so `_work.events`' subject reader and `log ID`'s own
--- render need nothing new taught to either. With no session resolved
--- the ` by` clause is dropped rather than written empty, the way
--- `new <id8> <title>` and `spec <id8>` carry no session at all.
--- @param id string The item's full id
--- @param session string The session, "" when none was resolved
--- @return string The subject line
local function entry_subject(id: string, session: string): string
  if (session or "") == "" then
    return ("note %s"):format(id:sub(1, 8))
  end
  return ("note %s by %s"):format(id:sub(1, 8), session)
end

--- Append one immutable entry under items/<id>/log. Metadata and
--- ranked children stay intact; a correction is another entry.
---
--- Confirmed publication patches the native cache during snapshot refresh.
--- The log path attributes the event to its item without changing item metadata.
--- @param s store.Store The store
--- @param id string The item id, already resolved by the dispatcher
--- @param file string Path to the file holding the entry's prose
--- @param session string | nil The session to attribute the entry to
--- @param force boolean | nil Append past another session's live claim
--- @param why string | nil Why --force was needed
--- @return integer Exit code
local function cmd_log_add(s: store.Store, id: string, file: string,
    session?: string, force?: boolean, why?: string): integer
  local frc = force or false
  local rsn = why or ""
  local forced = gate.force_refusal(frc, rsn)
  if forced then
    return verdict_line("log", false, "REFUSED: " .. forced)
  end
  local body, rerr = fs.read(file)
  if body == nil then
    return verdict_line("log", false, rerr)
  end
  local prose = (body:gsub("%s+$", ""))
  if prose == "" then
    return verdict_line("log", false,
      ("REFUSED: %s holds no prose — an entry is an observation, and an "
        .. "empty one records nothing"):format(file))
  end
  local worktree = storeinit.linked_worktree_refusal(s.root)
  if worktree ~= nil then
    return verdict_line("log", false, worktree)
  end
  local current, ferr = format.require_current(s.root)
  if not current then
    return verdict_line("log", false, ferr)
  end
  -- Observe the item's current tree and authority at this state head.
  local it, lerr = store.load(s, id)
  if it == nil then
    return verdict_line("log", false, lerr)
  end
  -- The same fence `gitgate.commit_and_publish` runs for mutations:
  -- a live claim held by someone else refuses the append.
  local refusal = claimgate.mutation_refusal(s, it, session or "", frc, rsn)
  if refusal ~= nil then
    return verdict_line("log", false, refusal)
  end
  local ref, tip = s.leased_ref[id], s.leased_sha[id]
  if ref == nil or tip == nil or tip == refs.ZERO_SHA then
    return verdict_line("log", false,
      ("%s carries no observed tip to append to"):format(tail.handle(id)))
  end
  local subject = entry_subject(id, session or "") .. gate.forced_suffix(frc, rsn)
  local old_session, old_op, old_bounded = s.session, s.op, s.bounded
  s.session, s.op, s.bounded = session or "", "note", false
  local ok, err = statewrite.log(s, it, subject, prose)
  s.session, s.op, s.bounded = old_session, old_op, old_bounded
  if not ok then return verdict_line("log", false, err) end
  local published, detail = publish.publish(s)
  if not published then return verdict_line("log", false, detail) end
  if detail ~= "" then print(detail) end
  local refreshed, refresh_err = store.load(s, id)
  if refreshed == nil then return verdict_line("log", false, refresh_err) end
  local _, newlines = prose:gsub("\n", "")
  return verdict_line("log", true,
    ("%s gained an entry (%d lines)"):format(tail.handle(id), newlines + 1))
end

local record gitlog
  heading: function(e: Entry): string
  log_report: function(entries: {Entry}, oneline?: boolean): {string}
  entry_subject: function(id: string, session: string): string
  cmd_log: function(s: store.Store, id: string, oneline?: boolean): integer
  cmd_log_add: function(s: store.Store, id: string, file: string,
  session?: string, force?: boolean, why?: string): integer
end

local M: gitlog = {
  heading = heading,
  log_report = log_report,
  entry_subject = entry_subject,
  cmd_log = cmd_log,
  cmd_log_add = cmd_log_add,
}

return M
