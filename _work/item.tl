--- One work item: a git ref, its tip commit's tree holding the fields
--- here and its prose spec (`_work.itemtree` is that shape). The
--- decode/encode this file itself carries — the literal-table form,
--- through `cosmic.literal` — is the OLD `items/<ksuid>.tl` layout;
--- `_work.import` is its only remaining caller, replaying a git
--- directory's history at the move into the ref layout. There is ONE
--- record and no kind field — an item's role emerges from where it
--- sits in the dependency graph, the same way a file's role in cosmic
--- emerges from its position:
---
---   the board  the one parentless item — never workable, never taken
---   an outcome a direct child of the board — decomposed, never taken
---   a container any item with open children, being decomposed
---   work       a childless item below the outcome level
---
--- The depth tests that tell these apart (`_work.flow.is_board`,
--- `_work.flow.is_outcome`) need more than one item to answer, so they
--- live in `_work.flow`, not here; this file only validates per-item
--- shape (fields, exclusivity rules) and, where a rule needs no more
--- than "does this item have a parent at all", tests that directly.
---
--- A workable item's state is DERIVED from the facts it carries,
--- never declared: open and unclaimed with no PR is `todo`; a claim
--- or a PR makes it `doing`; a non-empty resolution ends it. The
--- derivation lives in `_work.flow` — this file only validates
--- per-item shape (fields, exclusivity rules).
---
--- There is no goal tier either: every item is the same record, and
--- what makes one more important than another is its position in the
--- rank path (`_work.rank`), never a field asserting its own rank. The
--- outcome prose that gives the tree its meaning lives in
--- `docs/goals.md` on cosmic's own `main` and is read by people, not
--- by this.
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
  --- The owner/name the item's PR lands in. The board carries no repo
  --- at all (`problems` refuses one that does); every workable item
  --- should name one explicitly — most target `_work.product.REPO`,
  --- the product repo this board exists to move work on, and an item
  --- whose PR targets this board repository's own machinery instead
  --- names it explicitly too. "" reads as unset, never as "the
  --- board's own origin" the way it once did before the board moved
  --- out of cosmic's `board` branch into its own repository history.
  repo: string
  --- The branch the item's PR targets; "" = ungated — no verb checks
  --- it and no PR is refused for disagreeing. Set it once a non-default
  --- target is known — an item touching this board repository's own
  --- machinery names its `main`; `gitready.handover_refusal` compares
  --- it against the PR's own base ref.
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
  --- The research handover: the spec sidecar's revision
  --- (`_work.spec.revision`) as it stood when `take --result` handed
  --- the item over for a verdict; "" when none. The one deliverable
  --- is a diff OR board state, so `pr` and `result` never both stand,
  --- and a handover records work, so `result` never stands with no
  --- `builders`. `verdict` refuses when the sidecar has moved past it.
  result: string
  --- Standing review verdict: "" | "accept" | "request changes".
  --- A reject stands nowhere: it clears the claim and the PR, so the
  --- item is todo again and the learning lives in its spec.
  verdict: string
  --- Head commit the last verdict was written against.
  verdict_head: string
  --- The spec revision the verdict judged (`_work.spec.revision` of
  --- the sidecar as it stood). A review judges a diff AND the spec it
  --- is measured against, so the head alone cannot say whether a
  --- second look has anything new to see. "" on an item verdicted
  --- before the field existed — unknown, which is not the same as
  --- unchanged, and nothing may be concluded from it.
  verdict_spec: string
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
    builders = shape.optional(shape.string),
    speccers = shape.optional(shape.string),
    reviewer = shape.optional(shape.string),
    pr = shape.optional(shape.integer),
    result = shape.optional(shape.string),
    verdict = shape.optional(shape.string),
    verdict_head = shape.optional(shape.string),
    verdict_spec = shape.optional(shape.string),
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
  builders: string | nil
  speccers: string | nil
  reviewer: string | nil
  pr: integer | nil
  result: string | nil
  verdict: string | nil
  verdict_head: string | nil
  verdict_spec: string | nil
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
  if not is_open(it) and ((it.claim or "") ~= "" or (it.reviewer or "") ~= "") then
    out[#out + 1] = "a done item holds no claim and no review"
  end
  if is_parentless(it) and ((it.claim or "") ~= "" or (it.reviewer or "") ~= ""
    or (it.pr or 0) ~= 0
    or (it.verdict or "") ~= "" or (it.repo or "") ~= ""
    or (it.base or "") ~= "") then
    out[#out + 1] =
    "claim/reviewer/pr/verdict/repo/base belong to worked items, never the "
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
    builders = builders,
    speccers = speccers,
    reviewer = raw.reviewer or "",
    pr = raw.pr or 0,
    result = raw.result or "",
    verdict = raw.verdict or "",
    verdict_head = raw.verdict_head or "",
    verdict_spec = raw.verdict_spec or "",
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
  if (it.claim or "") ~= "" then t.claim = it.claim end
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
  if (it.verdict_spec or "") ~= "" then t.verdict_spec = it.verdict_spec end
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
