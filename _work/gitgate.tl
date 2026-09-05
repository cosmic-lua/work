--- The gate between the flow rules and the verbs: force/claim/distance
--- refusals, and the commit-and-publish every mutation goes through.
--- Every verb's verdict line is here too, so the read verbs need
--- nothing from the mutating ones. The spec bar itself —
--- `ready_problems` and what feeds it — is `_work.gitready`, split out
--- to keep this file under its line cap.
---
--- The rule these share: ONE mutation is ONE atomic push, though it
--- may be several commits — one per item `also` names alongside `it`.
--- A refused publish drops every one of them, so anything a mutation
--- touches beyond its subject travels with it rather than being
--- committed alongside.
local cache = require("_work.cache")
local fs = require("cosmic.fs")
local flow = require("_work.flow")
local health = require("_work.health")
local index = require("_work.index")
local item = require("_work.item")
local publish = require("_work.publish")
local read = require("_work.read")
local store = require("_work.store")
local storewrite = require("_work.storewrite")

local type Index = index.Index

--- Print a verb's verdict line and return its exit code.
--- @param verb string The verb
--- @param ok boolean Whether it succeeded
--- @param detail string What happened
--- @return integer 0 on success, 1 otherwise
local function verdict_line(verb: string, ok: boolean, detail: string): integer
  print(("gitboard-%s: %s"):format(verb, detail))
  if ok then
    return 0
  end
  return 1
end

--- The refusal a bare `--force` earns, or nil when the mutation may
--- proceed. `--force` is for repair, never for flow — and a forced
--- mutation with no stated reason is indistinguishable in the log from
--- an ordinary one, which is exactly what makes that rule
--- unenforceable after the fact.
--- @param force boolean Whether --force was passed
--- @param why string The stated reason
--- @return string | nil The refusal
local function force_refusal(force: boolean, why: string): string
  if not force or (why or ""):match("%S") ~= nil then
    return nil
  end
  return "--force needs --why <reason>: a forced mutation is a repair, "
  .. "and the log has to say what it repaired"
end

--- The suffix a forced mutation adds to its commit subject, so the
--- reason travels with the change rather than with the session.
--- @param force boolean Whether --force was passed
--- @param why string The stated reason
--- @return string The suffix, "" when nothing was forced
local function forced_suffix(force: boolean, why: string): string
  if not force then
    return ""
  end
  return (" (forced: %s)"):format(why)
end

--- The refusal a stale base earns, or nil when the write may proceed.
---
--- `spec` replaces the WHOLE sidecar, so the write has to say which
--- text it is replacing. The push half is a compare-and-swap already,
--- but it compares COMMITS: a session that synced between reading a
--- spec and writing its refinement back rebases cleanly over the write
--- it is erasing. The base is the missing half — the text the caller
--- read, compared against the text that is there.
---
--- One rule covers both calls, because an item with no sidecar reads
--- back "" and that is what a call with no `--base` compares against:
--- the FIRST write of a spec needs no flag, and every later one does.
--- @param current string The sidecar as it stands
--- @param base string The base file's path, "" when none was given
--- @param id string The item's full id, for the message and the path
--- @return string | nil The refusal
local function base_refusal(current: string, base: string,
    id: string): string | nil
  local claimed = ""
  if base ~= "" then
    local base_text, rerr = fs.read(base)
    if base_text == nil then
      return ("REFUSED: --base %s is unreadable: %s"):format(base, rerr)
    end
    claimed = base_text
  end
  if claimed == current then
    return nil
  end
  local id8 = id:sub(1, 8)
  if base == "" then
    return ("REFUSED: %s already has a spec — pass --base FILE holding the "
      .. "text you read; a write with no base is last-write-wins"):format(id8)
  end
  return ("REFUSED: %s's spec changed since you read it — re-read it "
    .. "(`gitboard show %s`), re-apply your edit, and pass the re-read "
    .. "text as --base"):format(id8, id8)
end

--- The refusal a foreign session's spec write earns on an item that is
--- in flight under someone else's claim, or nil when the write may
--- proceed. An in-flight item's spec is its claim holder's to move —
--- spec-only rework answering a bounce is a designed path, at any
--- point in the holder's own build — and a write to an unclaimed item
--- (todo, or dropped back to it) is nobody's to gate. Only a foreign
--- LIVE claim earns this: rewriting it needs `--force --why`, same as
--- taking one over.
--- @param c Index An index with `_work.readddl.ensure_views` applied
--- @param it item.Item The item whose spec would be rewritten
--- @param session string The session making the write
--- @return string | nil The refusal
--- @return string Error message
local function spec_refusal(c: Index, it: item.Item, session: string): string | nil, string
  local st, serr = read.state(c, it.id)
  if st == nil then
    return nil, serr
  end
  if st ~= "doing" then
    return nil, ""
  end
  if (it.claim or "") == "" then
    return nil, ""
  end
  if it.claim == (session or "") then
    return nil, ""
  end
  return ("REFUSED: %s is claimed by %s — rewriting another session's "
    .. "live build needs --force --why"):format(it.id:sub(1, 8), it.claim), ""
end

--- The board's claim and review claim leases past their horizon, split
--- by kind — `_work.read.stale`, read through the store's own open
--- cache. Shared by every takeover path (`take`, `take_review`,
--- `drop`) and the one-claim-per-session guard alike.
--- @param s store.Store The store
--- @return health.StaleAges | nil
--- @return string Error message
local function stale_ages(s: store.Store): health.StaleAges | nil, string
  local c, cerr = store.read(s)
  if c == nil then
    return nil, cerr
  end
  local rows, rerr = read.stale(c)
  if rows == nil then
    return nil, rerr
  end
  return health.from_rows(rows), ""
end

--- Whether `session` already built or specced this item — the
--- distance a review needs from either half of the decision: the
--- diff (`builders`) or the spec it answers to (`speccers`). Shared by
--- the review-claim derivation, which refuses outright with no escape
--- (a fresh context cannot be forced into existing), and verdict
--- recording, which allows `--force --why` as the audited repair path.
--- @param it item.Item The item under review
--- @param session string The session asking
--- @return string | nil The refusal
local function distance_refusal(it: item.Item, session: string): string | nil
  if (session or "") == "" then
    return nil
  end
  for _, name in ipairs(it.builders or {}) do
    if name == session then
      return ("REFUSED: %s built/specced %s — the verdict needs a fresh "
        .. "context; recording it anyway needs --force --why"):format(
        session, it.id:sub(1, 8))
    end
  end
  for _, name in ipairs(it.speccers or {}) do
    if name == session then
      return ("REFUSED: %s built/specced %s — the verdict needs a fresh "
        .. "context; recording it anyway needs --force --why"):format(
        session, it.id:sub(1, 8))
    end
  end
  return nil
end

--- The visibly unactioned finishing work standing between a session
--- and anything the unified order ranks below it: items at
--- `flow.STAGE_REVIEW` with no reviewer recorded, at a distance from
--- the session (the same `distance_refusal` the review claim asks).
--- Review is the one stage whose neglect the board can SEE — an
--- empty reviewer field is proof nobody is on it — where an accepted
--- item's merge and a claimed build leave no such trace, so only
--- review debt turns the ranking into a refusal. Deliberately LAXER
--- than `next`'s review rung on one point: any recorded reviewer
--- clears an item here, stale or live, because staleness needs
--- per-item git ages this gate does not read — a stale review still
--- drains through `next`, which offers taking it over ahead of any
--- pull. Laxer is the safe direction: every pull `next` offers as a
--- primary must pass this gate.
--- @param c Index An index with `_work.readddl.ensure_views` applied
--- @param items {item.Item} All items
--- @param session string The session asking to pull
--- @return {item.Item} | nil The debt, possibly empty, in queue order
--- @return string Error message
local function review_debt(c: Index, items: {item.Item},
    session: string): {item.Item} | nil, string
  local rows, err = read.queue(c)
  if rows == nil then
    return nil, err
  end
  local by_id = item.by_id(items)
  local out: {item.Item} = {}
  for _, row in ipairs(rows) do
    if row.stage == flow.STAGE_REVIEW then
      local i = by_id[row.id]
      if i ~= nil and (i.reviewer or "") == ""
      and distance_refusal(i, session) == nil then
        out[#out + 1] = i
      end
    end
  end
  return out, ""
end

--- The unified order as a take refusal, nil while the session may
--- take: refused whenever review debt stands, since every item this
--- gate ever runs for is itself todo or repair work (`_work.flow`'s
--- stage order ranks either well below review), so any debt at all
--- outranks the take by stage — the same order `next` serves the head
--- of, so the refusal is the ranking made binding, not a second rule.
--- The named review is the debt's head, already in queue order
--- (`review_debt`). One stated carve-out: a lane-repair take never
--- asks — the same arrival the doing bound never holds back, because a
--- red lane's fix cannot wait on a review queue it did not grow.
--- @param c Index An index with `_work.readddl.ensure_views` applied
--- @param items {item.Item} All items
--- @param session string The session asking to pull
--- @param taking item.Item The item about to be taken
--- @return string | nil The refusal
--- @return string Error message
local function review_debt_refusal(c: Index, items: {item.Item},
    session: string, taking: item.Item): string | nil, string
  if (taking.key or "") ~= "" then
    return nil, ""
  end
  local debt, derr = review_debt(c, items, session)
  if debt == nil then
    return nil, derr
  end
  if #debt == 0 then
    return nil, ""
  end
  local first = debt[1]
  local noun = "diff"
  if (first.result or "") ~= "" then noun = "handover" end
  return ("%d %s(s) await a verdict you can give and outrank this "
    .. "take — verdicts before new work: `take %s` claims the first; "
    .. "a recorded reviewer clears it"):format(#debt, noun, first.id:sub(1, 8)), ""
end

--- The refusal a NEW claim earns when `session` already holds a live
--- claim on another open item, or nil when it is free to claim. One
--- claim per name, so two runners sharing a session name collide
--- loudly here instead of silently corrupting mutual exclusion. Never
--- forced away — a collision is never repair, unlike a takeover — and
--- never asked about the item being claimed itself: a re-take of a
--- session's own item names no OTHER item and never refuses here.
--- @param s store.Store The store
--- @param all {item.Item} Every item
--- @param id string The item being claimed
--- @param session string The claiming session
--- @return string | nil The refusal
--- @return string Error message
local function second_claim_refusal(s: store.Store, all: {item.Item},
    id: string, session: string): string | nil, string
  if (session or "") == "" then
    return nil, ""
  end
  local ages, aerr = stale_ages(s)
  if ages == nil then
    return nil, aerr
  end
  for _, other in ipairs(all) do
    if other.id ~= id and item.is_open(other) and other.claim == session
    and not health.is_stale(other, ages.claim) then
      return ("REFUSED: %s already holds %s — one claim per worker; drop "
        .. "it or finish it first"):format(session, other.id:sub(1, 8)), ""
    end
  end
  return nil, ""
end

--- Save an item and publish the commit. Everything one mutation
--- touches goes in through `also`, so a lost race drops the whole
--- mutation rather than half of it. There is no post-race re-check
--- here: a lost push comes back as `store.LOST_RACE` with the
--- mutation dropped and the checkout synced, and the verb is run
--- again — which re-applies EVERY gate it decided with against the
--- merged board.
---
--- `verb` names the `Op:` trailer `save` adds to every commit this
--- call makes. `session`, when the caller has one, is threaded to
--- `save` as the write's author, through the store rather than
--- `save`'s own fixed signature. `bounded` marks a mutation whose
--- gates read the whole board before deciding (today: a NEW take
--- against the doing bound, and a lane mint) — `save` also advances
--- and leases `refs/heads/board/seq` for one of these, so two racing
--- bounded mutations cannot both land.
--- @param s store.Store The store
--- @param it item.Item The mutated item
--- @param body string Replacement spec markdown, or nil to leave the sidecar alone
--- @param message string Commit subject
--- @param verb string The verb name, recorded as the `Op:` trailer
--- @param also {item.Item} Further items the same mutation writes
--- @param session string | nil The session to credit as author, when known
--- @param bounded boolean | nil Whether this is a BOUNDED mutation
--- @return boolean True once committed (and pushed, given a remote), or a no-op
--- @return string Error; `store.LOST_RACE` for a lost race, `store.is_noop` for a no-op
local function commit_and_publish(s: store.Store, it: item.Item, body: string,
    message: string, verb: string, also?: {item.Item}, session?: string,
    bounded?: boolean): boolean, string
  storewrite.set_session(s, session or "")
  storewrite.set_op(s, verb)
  storewrite.set_bounded(s, bounded or false)
  -- Read before the write moves anything, so `after_save` below has
  -- proof the cache was valid immediately beforehand — see
  -- `_work.cache`'s own header for why this lives here rather than
  -- inside `storewrite.save` itself. `s.board_digest` is `store.list`'s
  -- own ref-snapshot digest, already covering the SAME watched
  -- namespaces the guard would otherwise re-read fresh — "" (unset,
  -- when the caller loaded by id rather than by listing the board)
  -- falls through to that fresh read exactly as before.
  local before_digest = cache.guard(s.root, s.board_digest)
  -- A pre-write snapshot of exactly the shas this save might move —
  -- `after_save` below diffs it against `s.leased_sha` post-write to
  -- tell which of `it`/`also` actually landed a new commit (a diff
  -- can find nothing to write for one of them), which is the only way
  -- to know without `_work.storewrite`/`_work.gitwrite` surfacing it.
  local before_shas: {string: string} = {[it.id] = s.leased_sha[it.id]}
  for _, x in ipairs(also or {}) do
    before_shas[x.id] = s.leased_sha[x.id]
  end
  local saved, serr = storewrite.save(s, it, message, body, also)
  if not saved or store.is_noop(serr) then
    return saved, serr
  end
  -- `it` first, then `also` — the cache patches straight from these,
  -- exactly as `storewrite.save` just wrote them, with no git read of
  -- its own; only `it` (`items[1]`) can carry a spec change (`body`), so
  -- that is the only slot `after_save` ever reindexes with new text.
  local items: {item.Item} = {it}
  for _, x in ipairs(also or {}) do
    items[#items + 1] = x
  end
  local written: {string: string} = {}
  for _, x in ipairs(items) do
    local new_sha = s.leased_sha[x.id]
    if new_sha ~= nil and new_sha ~= before_shas[x.id] then
      written[x.id] = new_sha
    end
  end
  cache.after_save(s.root, before_digest, items, body, message, written,
    s.written_at)
  -- The cache file's own digest just moved (`after_save`'s patch
  -- recorded it), but `s.index` — the CONNECTION this store has held
  -- open since its first read — did not: a prepared statement query_one
  -- checked out and released without a query in between never resets,
  -- which pins that connection's OWN read snapshot to whatever it was
  -- at that statement's last step — a `cosmic.sqlite` behavior no
  -- in-connection re-read can undo. Closing the handle here, rather
  -- than leaving it standing, is what makes the NEXT `store.read`/
  -- `list` reopen against the fresh digest instead of handing a
  -- follow-up mutation this store makes a guard already behind what
  -- it just wrote — the reopen is a cheap reuse, never a rebuild,
  -- since the file's own digest already matches.
  local _cok, _cerr = store.close(s)
  return publish.publish(s)
end

--- The locks a decomposition clears on the parent that just gained a
--- child: it is no longer workable, so a claim or review standing on
--- it locks nothing anyone can build. A DONE outcome reopens the same
--- way: filing or attaching a child under it is evidence against it,
--- so its resolution clears too — verified and retired outcomes
--- alike, no separate verb. The board itself never carries a
--- resolution to reopen (`_work.gitdoneroot` refuses `done` on it
--- outright), so `index` is only ever consulted to tell an outcome
--- from anything else.
---
--- Returned rather than saved, so the caller commits it TOGETHER with
--- the child; committed on its own it would survive a refused child.
--- @param c Index An index with `_work.readddl.ensure_views` applied
--- @param parent item.Item The item that gained a child
--- @return {item.Item} | nil The parent when it changed, empty otherwise
--- @return string Error message
local function containered(c: Index, parent: item.Item): {item.Item} | nil, string
  local role, rerr = read.role(c, parent.id)
  if role == nil then
    return nil, rerr
  end
  local reopened = role == "outcome" and (parent.resolution or "") ~= ""
  if (parent.claim or "") == "" and (parent.reviewer or "") == ""
  and not reopened then
    return {}, ""
  end
  parent.claim = ""
  parent.reviewer = ""
  if reopened then
    parent.resolution = ""
  end
  return {parent}, ""
end

local record gitgate
  verdict_line: function(verb: string, ok: boolean, detail: string): integer
  force_refusal: function(force: boolean, why: string): string
  forced_suffix: function(force: boolean, why: string): string
  base_refusal: function(current: string, base: string, id: string): string
  spec_refusal: function(c: Index, it: item.Item, session: string): string, string
  stale_ages: function(s: store.Store): health.StaleAges | nil, string
  distance_refusal: function(it: item.Item, session: string): string
  review_debt: function(c: Index, items: {item.Item}, session: string):
  {item.Item} | nil, string
  review_debt_refusal: function(c: Index, items: {item.Item}, session: string,
  taking: item.Item): string, string
  second_claim_refusal: function(s: store.Store, all: {item.Item},
  id: string, session: string): string, string
  commit_and_publish: function(s: store.Store, it: item.Item, body: string,
  message: string, verb: string, also?: {item.Item}, session?: string,
  bounded?: boolean): boolean, string
  containered: function(c: Index, parent: item.Item): {item.Item} | nil, string
end

local M: gitgate = {
  verdict_line = verdict_line,
  force_refusal = force_refusal,
  forced_suffix = forced_suffix,
  base_refusal = base_refusal,
  spec_refusal = spec_refusal,
  stale_ages = stale_ages,
  distance_refusal = distance_refusal,
  review_debt = review_debt,
  review_debt_refusal = review_debt_refusal,
  second_claim_refusal = second_claim_refusal,
  commit_and_publish = commit_and_publish,
  containered = containered,
}

return M
