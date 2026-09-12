--- One work item: a git ref whose tip tree holds these fields and its prose
--- spec (`_work.itemtree`). This decoder also supports the old literal-table
--- import layout. Role and state are derived from graph position and lifecycle
--- facts; this module validates only one item's shape.
local identity = require("_work.identity")
local ksuid = require("_work.ksuid")
local shape = require("cosmic.shape")

--- The most parent hops a walk up the tree takes before giving up:
--- deeper nesting than this is its own design smell, and a chain this
--- long is cyclic in practice. `_work.rank` and `_work.flow` both walk
--- parent chains and share this one bound.
local MAX_DEPTH < const > = 16

local record Item
  --- The filename stem and the one name other items use: a KSUID.
  id: string
  title: string
  --- The id this item decomposes; "" for the board, the one parentless
  --- item.
  parent: string
  --- Product repository, as owner/name; "" is unset.
  repo: string
  --- Product base branch; "" is unset.
  base: string
  --- The scheduled workflow file this item repairs; "" for ordinary
  --- items. `_work.lanes.mint`'s idempotency key: at most one OPEN
  --- item may carry a given key.
  key: string
  --- This item's ranked children, in rank order. Stored as one "id id"
  --- string — the literal domain has no lists. Empty when it has
  --- ranked none; an unranked child is simply absent from the list.
  order: {string}
  --- Edge kinds this reader does not interpret, carried opaquely so a
  --- tree written by a newer reader round-trips unchanged: kind -> id
  --- -> content (the reason, possibly ""). Never rendered by any verb
  --- and never validated here; `_work.itemtree` is the only reader and
  --- writer of it, and `gitboard fsck` is the only verb that reports
  --- on it at all.
  other_edges: {string: {string: string}} | nil
  --- The session that claimed it; "" when unclaimed.
  claim: string
  --- Product commit the current claim started from. Claims use this
  --- immutable base to name their work branch and to verify the change
  --- eventually handed over. nil/"" on unclaimed items and claims made
  --- before the lease redesign.
  claim_base: string | nil
  --- Immutable claim-batch commit projected into `claim`/`claim_base` on
  --- read. This pointer is durable item data; the projected facts are not.
  claim_batch: string | nil
  --- Product commit handed over for review. It is navigation-independent:
  --- the caller may also record an external URL, but this commit alone is
  --- what verdict and completion gates consume.
  handover_head: string | nil
  --- Optional provider-neutral navigation URL. No state transition or gate
  --- depends on it.
  external_url: string | nil
  --- Every session that has held the claim, oldest first. Stored as
  --- one "name name" string — the literal domain has no lists.
  ---
  --- The claim is a LEASE and moves: a drop clears it and the next
  --- take writes a new one, so the claim alone cannot answer "who has
  --- worked this item". This is that answer — the audit record, never
  --- cleared while the item is open, so who built and who took over
  --- stays readable in the committed file and in the log after the
  --- fact. Outside this module nothing reads it: no verb renders it
  --- and none refuses on it.
  builders: {string}
  --- Every session that has replaced this item's spec sidecar, oldest
  --- first. Stored and validated exactly like `builders` — same
  --- space-joined string, same no-repeats rule — because the
  --- no-self-review guarantee needs authorship of the SPEC recorded
  --- too: a session offered the review of a decision it wrote is the
  --- same hole `builders` closes for the diff.
  speccers: {string}
  --- The session reviewing the item's PR; "" when nobody claimed the
  --- review. A lease like `claim`, on a shorter horizon
  --- (`_work.health`): the claim is pushed BEFORE the reading starts,
  --- the verdict consumes it.
  reviewer: string
  --- The PR under review; 0 when none.
  pr: integer
  --- The research handover: the BOARD commit the applied
  --- recommendation sits on — the item ref's tip as it stood when
  --- `take --result` handed the item over for a verdict; "" when none.
  --- The one deliverable is a diff OR board state, so `pr` and
  --- `result` never both stand, and a handover records work, so
  --- `result` never stands with no `builders`. A value written before
  --- format 5 is a 40-hex digest of the spec blob instead, resolving
  --- to no board commit at all; nothing resolves this field as an
  --- object either way, and the next handover re-types it.
  result: string
  --- Standing review verdict: "" | "accept" | "request changes".
  --- A reject stands nowhere: it clears the claim and the PR, so the
  --- item is todo again and the learning lives in its spec.
  verdict: string
  --- Head commit the last verdict was written against.
  verdict_head: string
  --- Product commit recorded when accepted work is completed. Empty on an
  --- open item and on non-completed resolutions.
  landed_head: string | nil
  --- Why a finished item ended: "completed" | "not-planned"; "" while
  --- open. A non-empty resolution IS what "done" means.
  resolution: string
  --- Content problems `decode` found on this item (`problems(it)`,
  --- possibly several), carried alongside a successful decode instead
  --- of failing it — a read-time snapshot, not a stored fact: nil for
  --- an item built directly (never decoded) or freshly re-decoded
  --- clean, and never written back by `encode`. See `decode` and
  --- `is_flagged`.
  decode_problems: {string} | nil
end

--- The shape `decode`'s input must have. Every field is optional —
--- the literal domain omits zero values on write (see `encode`), so
--- an absent key is ordinary, not a mismatch — and nothing here is
--- coerced: a wrong-typed field is a refusal, not a silent zero.
--- `order` and `builders` validate as the space-joined strings the
--- file actually carries; splitting them into lists is a transform
--- `decode` still does after validation.
local SPEC < const > = shape.record({
    id = shape.optional(shape.string),
    title = shape.optional(shape.string),
    parent = shape.optional(shape.string),
    repo = shape.optional(shape.string),
    base = shape.optional(shape.string),
    key = shape.optional(shape.string),
    order = shape.optional(shape.string),
    claim = shape.optional(shape.string),
    claim_base = shape.optional(shape.string),
    claim_batch = shape.optional(shape.string),
    handover_head = shape.optional(shape.string),
    external_url = shape.optional(shape.string),
    builders = shape.optional(shape.string),
    speccers = shape.optional(shape.string),
    reviewer = shape.optional(shape.string),
    pr = shape.optional(shape.integer),
    result = shape.optional(shape.string),
    verdict = shape.optional(shape.string),
    verdict_head = shape.optional(shape.string),
    landed_head = shape.optional(shape.string),
    resolution = shape.optional(shape.string),
  })

--- The type `shape.into` hands `decode` back: SPEC typed, with every
--- field still optional since the Spec admits absence. Not `Item` —
--- the space-joined list fields and the zero-value defaults are still
--- raw here; `decode` derives `Item` from this after validation.
local record Raw
  id: string | nil
  title: string | nil
  parent: string | nil
  repo: string | nil
  base: string | nil
  key: string | nil
  order: string | nil
  claim: string | nil
  claim_base: string | nil
  claim_batch: string | nil
  handover_head: string | nil
  external_url: string | nil
  builders: string | nil
  speccers: string | nil
  reviewer: string | nil
  pr: integer | nil
  result: string | nil
  verdict: string | nil
  verdict_head: string | nil
  landed_head: string | nil
  resolution: string | nil
end

--- The valid `verdict` values, exported so a schema carrying its own
--- copy of this vocabulary (`_work.index`'s DDL `CHECK IN (...)`) can
--- be proven to name exactly these and no others.
local VERDICTS: {string: boolean} = {
  [""] = true,
  ["accept"] = true,
  ["request changes"] = true,
}

--- The valid `resolution` values, exported for the same reason as
--- `VERDICTS`.
local RESOLUTIONS: {string: boolean} = {
  [""] = true,
  ["completed"] = true,
  ["not-planned"] = true,
}

--- Whether an item is open: done is nothing more than a recorded
--- resolution.
--- @param it Item The item
--- @return boolean True while resolution is empty
local function is_open(it: Item): boolean
  return (it.resolution or "") == ""
end

--- Whether `it` already stands in the substate `_work.indexddl`'s
--- `substate` view names "review" (a handed-over commit with no verdict
--- yet) or "rework" (a standing "request changes") — matching that
--- view's own CASE exactly, branch for branch. `pr` and `result` remain
--- read compatibility for pre-v3 item trees.
--- `_work.gitgate.containered` reads this to leave such a parent's
--- role and its live claim/handover untouched when a routine child lands on
--- it, rather than treating the child as a decomposition. This is a
--- broader test than `_work.gitverbs.cmd_take`'s own review-claim
--- eligibility, which additionally needs a handover to exist
--- (there being nothing to claim a review of otherwise) — that check
--- stays inline in `cmd_take`, not routed through here.
--- @param it Item The item
--- @return boolean True while it carries a standing "request changes",
--- or an empty verdict with a commit handover awaiting one
local function is_review_or_rework(it: Item): boolean
  local verdict = it.verdict or ""
  if verdict == "request changes" then
    return true
  end
  if verdict ~= "" then
    return false
  end
  return (it.handover_head or "") ~= "" or (it.pr or 0) ~= 0
  or (it.result or "") ~= ""
end

--- Whether an item is parentless — the board, in a well-formed tree,
--- and the one shape check this file itself needs (below): a second
--- parentless item is a fsck finding (`_work.gitfsck`), never this
--- module's to decide. `_work.flow.is_board` is the one other caller
--- that needs this test; everywhere else that used to ask "is this a
--- root" now asks a depth question `_work.flow` alone can answer
--- (`is_board`, `is_outcome`).
--- @param it Item The item
--- @return boolean True when parentless
local function is_parentless(it: Item): boolean
  return (it.parent or "") == ""
end

--- Items indexed by id.
local type Index = {string: Item}

--- Every item indexed by its own id — the one lookup nearly every
--- graph walk in `_work.rank` and `_work.flow` needs first.
--- @param items {Item} All items
--- @return Index Items by id
local function by_id(items: {Item}): Index
  local out: Index = {}
  for _, i in ipairs(items) do
    out[i.id] = i
  end
  return out
end

--- The problems an item has on its own, empty when it is valid. One
--- list rather than first-failure, so a hand-edited file reports
--- everything wrong with it at once.
--- @param it Item The item
--- @return {string} Problems, possibly empty
local function problems(it: Item): {string}
  local out: {string} = {}
  if not ksuid.is_id(it.id or "") then
    out[#out + 1] = ("id must be a ksuid: %s"):format(tostring(it.id))
  end
  if it.title == nil or it.title == "" then
    out[#out + 1] = "title must be non-empty"
  elseif it.title:find("[\n\r]") ~= nil then
    out[#out + 1] = "title must be one line: no newlines"
  elseif it.title ~= it.title:match("^%s*(.-)%s*$") then
    out[#out + 1] = "title must not have leading or trailing whitespace"
  end
  if not VERDICTS[it.verdict or ""] then
    out[#out + 1] = ("unknown verdict: %s"):format(tostring(it.verdict))
  end
  if not RESOLUTIONS[it.resolution or ""] then
    out[#out + 1] = ("unknown resolution: %s"):format(tostring(it.resolution))
  end
  local handover_head = it.handover_head or ""
  if handover_head ~= "" and (not handover_head:match("^[0-9a-f]+$")
    or (#handover_head ~= 40 and #handover_head ~= 64)) then
    out[#out + 1] = "handover_head must be a full lowercase commit id"
  end
  local landed_head = it.landed_head or ""
  if landed_head ~= "" and (not landed_head:match("^[0-9a-f]+$")
    or (#landed_head ~= 40 and #landed_head ~= 64)) then
    out[#out + 1] = "landed_head must be a full lowercase commit id"
  end
  local claim_batch = it.claim_batch or ""
  if claim_batch ~= "" and (#claim_batch ~= 40
    or claim_batch:match("^[0-9a-f]+$") == nil) then
    out[#out + 1] = "claim_batch must be a full lowercase commit id"
  end
  local external_url = it.external_url or ""
  if external_url ~= "" and not external_url:match("^https?://%S+$") then
    out[#out + 1] = "external_url must be one http(s) URL"
  end
  if handover_head ~= "" and (it.verdict_head or "") ~= ""
  and it.verdict_head ~= handover_head then
    out[#out + 1] = "verdict_head must equal the handed-over commit"
  end
  if landed_head ~= "" and it.resolution ~= "completed" then
    out[#out + 1] = "landed_head belongs only to completed items"
  end
  if not is_open(it) and (it.reviewer or "") ~= "" then
    out[#out + 1] = "a done item holds no review"
  end
  if is_parentless(it) and ((it.reviewer or "") ~= ""
    or (it.pr or 0) ~= 0
    or (it.verdict or "") ~= "" or (it.repo or "") ~= ""
    or (it.base or "") ~= "") then
    out[#out + 1] =
    "reviewer/pr/verdict/repo/base belong to worked items, never the "
    .. "board"
  end
  if (it.pr or 0) ~= 0 and (it.result or "") ~= "" then
    out[#out + 1] = "pr and result never both stand: a deliverable is a diff "
    .. "or board state, never both"
  end
  if (it.result or "") ~= "" and #(it.builders or {}) == 0 then
    out[#out + 1] = "result records a handover, and an item nobody built has "
    .. "no work to hand over"
  end
  if (it.repo or "") ~= "" and not it.repo:match("^[%w%-%.]+/[%w%-%._]+$") then
    out[#out + 1] = ("repo must be owner/name: %s"):format(it.repo)
  end
  if (it.base or "") ~= "" and not it.base:match("^[%w%-%._/]+$") then
    out[#out + 1] = ("base must be a branch name: %s"):format(it.base)
  end
  local built_seen: {string: boolean} = {}
  for _, name in ipairs(it.builders or {}) do
    if built_seen[name] then
      out[#out + 1] = ("builders repeats %s"):format(name)
    else
      built_seen[name] = true
    end
  end
  local specced_seen: {string: boolean} = {}
  for _, name in ipairs(it.speccers or {}) do
    if specced_seen[name] then
      out[#out + 1] = ("speccers repeats %s"):format(name)
    else
      specced_seen[name] = true
    end
  end
  return out
end

--- Split one of the space-joined list fields (`order`, `builders`,
--- `speccers`) back into a list.
--- @param joined string | nil The space-joined field; "" or nil is empty
--- @return {string} The list, possibly empty
local function split_ids(joined: string | nil): {string}
  local out: {string} = {}
  for ref in (joined or ""):gmatch("%S+") do
    out[#out + 1] = ref
  end
  return out
end

--- An item from the table `cosmic.literal` parsed, with zero values
--- filled in and every field shape-checked. Unknown keys are ignored,
--- so a file carrying retired fields still reads — and sheds them on
--- its next write. The OLD `items/<id>.tl` layout's decode:
--- `_work.import` is the one remaining caller, reading a historical
--- commit's file content on its way into the ref layout;
--- `_work.itemtree.to_item` is the live decode every read (`store.load`,
--- `store.list`) actually goes through.
---
--- This fails hard only on genuine corruption: an unparseable literal
--- or a field of the wrong type (`shape.into` against `SPEC`, below).
--- A CONTENT problem — `problems(it)` non-empty: a claimed parentless
--- item, a repeated blocker, and so on — does not fail the decode; the
--- constructed `Item` comes back with `problems(it)` attached at
--- `.decode_problems` instead (`is_flagged` reads it) — a historical
--- commit written by an older or less careful writer still replays.
--- @param t {string: any} Parsed literal table
--- @return Item | nil The item, present even with content problems
--- @return string Error message; set only when the literal is corrupt
local function decode(t: {string: any}): Item | nil, string
  local raw, err: Raw | nil, string = shape.into(t, SPEC)
  if not raw then
    return nil, err
  end
  local order = split_ids(raw.order)
  local builders = split_ids(raw.builders)
  local speccers = split_ids(raw.speccers)
  local it: Item = {
    id = raw.id or "",
    title = raw.title or "",
    parent = raw.parent or "",
    repo = raw.repo or "",
    base = raw.base or "",
    key = raw.key or "",
    order = order,
    claim = raw.claim or "",
    claim_base = raw.claim_base or "",
    claim_batch = raw.claim_batch or "",
    handover_head = raw.handover_head or "",
    external_url = raw.external_url or "",
    builders = builders,
    speccers = speccers,
    reviewer = raw.reviewer or "",
    pr = raw.pr or 0,
    result = raw.result or "",
    verdict = raw.verdict or "",
    verdict_head = raw.verdict_head or "",
    landed_head = raw.landed_head or "",
    resolution = raw.resolution or "",
  }
  local bad = problems(it)
  if #bad > 0 then
    it.decode_problems = bad
  end
  return it
end

--- Whether `decode` flagged content problems on this item. Read-path
--- tolerance only: a freshly `decode`d item that is actually clean
--- reports false the same as one built directly and never decoded.
--- @param it Item The item
--- @return boolean True when `.decode_problems` names at least one
local function is_flagged(it: Item): boolean
  return #(it.decode_problems or {}) > 0
end

--- The literal table form of an item: zero values omitted, so a diff
--- of it shows only what moved. `decode`'s inverse; together they are
--- what `_work.import` round-trips a historical commit through.
--- @param it Item The item
--- @return {string: any} Table for `cosmic.literal.format`/`format_file`
local function encode(it: Item): {string: any}
  local t: {string: any} = {
    id = it.id,
    title = it.title,
  }
  if (it.parent or "") ~= "" then t.parent = it.parent end
  if (it.repo or "") ~= "" then t.repo = it.repo end
  if (it.base or "") ~= "" then t.base = it.base end
  if (it.key or "") ~= "" then t.key = it.key end
  if #(it.order or {}) > 0 then t.order = table.concat(it.order, " ") end
  if (it.claim_batch or "") ~= "" then t.claim_batch = it.claim_batch end
  if (it.handover_head or "") ~= "" then t.handover_head = it.handover_head end
  if (it.external_url or "") ~= "" then t.external_url = it.external_url end
  if #(it.builders or {}) > 0 then
    t.builders = table.concat(it.builders, " ")
  end
  if #(it.speccers or {}) > 0 then
    t.speccers = table.concat(it.speccers, " ")
  end
  if (it.reviewer or "") ~= "" then t.reviewer = it.reviewer end
  if (it.pr or 0) ~= 0 then t.pr = it.pr end
  if (it.result or "") ~= "" then t.result = it.result end
  if (it.verdict or "") ~= "" then t.verdict = it.verdict end
  if (it.verdict_head or "") ~= "" then t.verdict_head = it.verdict_head end
  if (it.landed_head or "") ~= "" then t.landed_head = it.landed_head end
  if (it.resolution or "") ~= "" then t.resolution = it.resolution end
  return t
end

local record item
  type Item = Item
  type Index = Index
  MAX_DEPTH: integer
  VERDICTS: {string: boolean}
  RESOLUTIONS: {string: boolean}
  is_open: function(it: Item): boolean
  is_review_or_rework: function(it: Item): boolean
  is_parentless: function(it: Item): boolean
  is_flagged: function(it: Item): boolean
  by_id: function(items: {Item}): Index
  problems: function(it: Item): {string}
  identity_refusal: function(session: string): string
  record_involvement: function(list: {string}, session: string): boolean, string
  decode: function(t: {string: any}): Item | nil, string
  encode: function(it: Item): {string: any}
end

local M: item = {
  MAX_DEPTH = MAX_DEPTH,
  VERDICTS = VERDICTS,
  RESOLUTIONS = RESOLUTIONS,
  is_open = is_open,
  is_review_or_rework = is_review_or_rework,
  is_parentless = is_parentless,
  is_flagged = is_flagged,
  by_id = by_id,
  problems = problems,
  identity_refusal = identity.identity_refusal,
  record_involvement = identity.record_involvement,
  decode = decode,
  encode = encode,
}

return M
