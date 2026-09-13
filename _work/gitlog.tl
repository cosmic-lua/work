--- The `log ID` verb: one item's own commit history, newest first,
--- and `log ID --add FILE`, the one way to put something INTO it.
--- Every retrospective fact an item carries — what was measured, what
--- was found, what happened along the way — lives in the message
--- bodies on its ref, and this is the verb that shows them; the item's
--- tree carries only its current state, which `show ID` renders.
---
--- The read half is PURE over already-read state, like every read
--- verb, and its `cmd_` half owns the store reads: what a session
--- reads is the contract, and a report that returns its lines can be
--- asserted on without capturing stdout.
---
--- The append half is the only write here, and it moves nothing: its
--- commit's tree is IDENTICAL to its parent's, so an observation about
--- an item no longer has to wait for a mutation to ride along with.
--- That shape is why it writes its own stream (`_work.fastimport`)
--- instead of going through `_work.storewrite.save`, whose per-path
--- diff finds nothing to write and reports the no-op — which is also
--- why it runs the claim fence itself: an entry lands a commit on the
--- item's ref, and a ref under a live claim is the holder's to move,
--- so a foreign append is refused exactly as every other mutation of
--- a claimed item is (`_work.gitclaimgate`), with `--force --why` the
--- one audited way past it. The fence is what keeps the claim's
--- staleness horizon honest: an item's freshness is its ref's newest
--- commit, so a stranger who could append would keep a dead claim
--- alive by writing notes; the holder's own entries advancing it is
--- right, since the holder is active.
local cache = require("_work.cache")
local claimgate = require("_work.gitclaimgate")
local fastimport = require("_work.fastimport")
local format = require("_work.format")
local fs = require("cosmic.fs")
local gate = require("_work.gitgate")
local gitdraft = require("_work.gitdraft")
local gitreadlog = require("_work.gitreadlog")
local publish = require("_work.publish")
local refs = require("_work.refs")
local store = require("_work.store")
local storeinit = require("_work.storeinit")
local storewrite = require("_work.storewrite")
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
local TOOL_NAME < const > = "Claude"
local TOOL_EMAIL < const > = "noreply@anthropic.com"

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

--- Append one entry to an item's history: a commit on the item's own
--- ref carrying `file`'s prose as its message body and NOTHING else —
--- no field, no sidecar, no ranked child — so its tree is identical to
--- the tree its parent already carries. An entry is IMMUTABLE: there
--- is no edit and no delete, and a correction is another entry.
---
--- The board cache is patched exactly as every other write patches it
--- (`_work.cache.guard` before, `after_save` after), for the reason
--- that path exists at all: an append moves the item's ref, so the
--- board's ref digest moves with it, and a cache left behind makes the
--- NEXT whole-board read pay for a full rebuild — measured at 20x on
--- the live board, which would make the cheap way to record an
--- observation the most expensive mutation there is. What is patched
--- is only the two things that actually moved — the item's write lease
--- and one `events` row for the new commit — never the entry's prose,
--- which is read from the ref like every other message body. The
--- patch's own guard makes this unable to fail: a digest that moved
--- under us, or no cache file at all, is silently skipped and the next
--- read rebuilds as it would have anyway.
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
  -- `store.load` proves the id names a real ref and leaves the lease
  -- behind: the ref this entry lands on, and the tip its commit has to
  -- fast-forward from. The item itself is what the cache patch below
  -- writes its row from, with no git read of its own.
  local it, lerr = store.load(s, id)
  if it == nil then
    return verdict_line("log", false, lerr)
  end
  -- The same fence `gitgate.commit_and_publish` runs for every other
  -- item-ref mutation, over the claim state `store.load` just leased:
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
  local author_name, author_email = TOOL_NAME, TOOL_EMAIL
  if (session or "") ~= "" then
    author_name, author_email = session, session .. "@board"
  end
  -- A forced append carries its reason in the subject, the way every
  -- forced mutation's subject does, so the audit travels with the
  -- commit rather than with the session.
  local subject = entry_subject(id, session or "") .. gate.forced_suffix(frc, rsn)
  local now = fastimport.git_date_now()
  -- The epoch second the commit itself carries, so the lease and the
  -- `events` row the patch records name the same instant git does.
  local written_at = fastimport.git_date_seconds(now)
  -- Read the cache's state BEFORE anything moves: that is the proof it
  -- was current immediately beforehand, which is what makes patching
  -- one item safe rather than trusting a maybe-stale file. `store.load`
  -- never opened the cache, so `s.board_digest` is "" here and the
  -- guard takes a fresh digest of its own.
  local before_digest = cache.guard(s.root, s.board_digest)
  -- No path ops at all: `from` carries the parent's whole tree
  -- forward, which is the whole of what makes the commit
  -- tree-identical.
  local ok, werr = fastimport.run(s.root, {{
        ref = ref, from = tip, author_name = author_name,
        author_email = author_email, author_date = now,
        committer_name = TOOL_NAME, committer_email = TOOL_EMAIL,
        committer_date = now, message = subject .. "\n\n" .. prose,
        op = "note", ops = {},
      }})
  if not ok then
    return verdict_line("log", false, werr)
  end
  -- fast-import refuses a non-fast-forward `from` silently — no ref
  -- moved, no non-zero exit — so "the ref did not move off the tip we
  -- observed" is read back here as the compare-and-swap failure it is,
  -- exactly the way `_work.gitwrite` reads its own back.
  local moved, merr = refs.read_ref(s.root, ref)
  if moved == nil then
    return verdict_line("log", false, merr)
  end
  if moved == tip or moved == refs.ZERO_SHA then
    return verdict_line("log", false,
      ("fast-import did not fast-forward %s — refused (unexpected local "
        .. "state)"):format(ref))
  end
  storewrite.add_pending(s, {ref = ref, old = tip})
  -- Advance the store's lease past the write, the way `storewrite.save`
  -- does after its own: a later write through this same handle has to
  -- lease against the entry's commit, not the tip it was appended to.
  -- The item's fields did not move, so its snapshot is re-taken as is.
  s.fresh_lease = ""
  s.leased_sha[id] = moved
  s.leased_item[id] = store.snapshot_item(it)
  s.written_at = written_at
  -- `written` names the one id that gained a commit, which is what
  -- earns it the lease change and the `events` row; the item's fields
  -- are patched from `it` exactly as observed, and nil for the spec
  -- body leaves its indexed prose alone. A remote-backed save is only
  -- PREPARED at this point, so patching would publish unconfirmed
  -- state; a draft patches once its own staging has landed instead.
  local written: {string: string} = {[id] = moved}
  if refs.board_mode(s.root) == "local" and gitdraft.active(s.root) == nil then
    cache.after_save(s.root, before_digest, {it}, nil, subject, written, written_at)
  end
  local _cok, _cerr = store.close(s)
  local published, detail = publish.publish(s)
  if not published then
    return verdict_line("log", false, detail)
  end
  if gitdraft.active(s.root) ~= nil then
    cache.after_save(s.root, before_digest, {it}, nil, subject, written, written_at)
  end
  if (detail or "") ~= "" then
    print(detail)
  end
  local n = 1
  for _ in prose:gmatch("\n") do
    n = n + 1
  end
  return verdict_line("log", true,
    ("%s gained an entry (%d %s)"):format(tail.handle(id), n,
      n == 1 and "line" or "lines"))
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
