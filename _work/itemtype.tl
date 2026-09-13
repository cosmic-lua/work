--- The item record and the id-keyed index over it: declarations and
--- their doc comments, nothing else. Split out of `_work.item`, which
--- sits against the repo's line cap, so the record can carry its
--- declared fields without the validation, codec and predicates beside
--- it going over. This module requires nothing, and `_work.item`
--- requires it one way, so nothing here can create a cycle; every
--- `item.Item`/`item.Index` reference elsewhere keeps resolving through
--- `_work.item`'s own aliases.

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
  --- The files this change is expected to touch, declared by the
  --- refiner rather than scraped from prose. Advisory: nothing refuses
  --- on it, and collision detection reads it.
  touches: {string}
  --- The repositories this work needs beyond the item's own `repo`, as
  --- owner/name slugs. What a spec used to state under `## Access`,
  --- declared instead.
  access: {string}
  --- The item ids this one may not start before, a set of zero or
  --- more. Gates whether the item is pullable and has no effect on
  --- rank: parentage says where in the queue, dependency whether this
  --- may start.
  depends_on: {string}
  --- Content problems `decode` found on this item (`problems(it)`,
  --- possibly several), carried alongside a successful decode instead
  --- of failing it — a read-time snapshot, not a stored fact: nil for
  --- an item built directly (never decoded) or freshly re-decoded
  --- clean, and never written back by `encode`. See `decode` and
  --- `is_flagged`.
  decode_problems: {string} | nil
end

--- Items indexed by id.
local type Index = {string: Item}

local record itemtype
  type Item = Item
  type Index = Index
end

local M: itemtype = {}

return M
