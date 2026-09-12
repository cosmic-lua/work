## Change

Decompose the replacement of an item's free-markdown `spec.md` sidecar
with a typed schema. The evidence, the design, and the order its children
land in are `docs/design/schema.md` on this repository's `main`; the
tradeoffs are D47 and D48 in cosmic-lua/cosmic. This item is decomposed,
never taken.

The shape, in one paragraph so a reader need not open the design: a spec
is prospective and is replaced, a measurement is retrospective and is
appended, and the tree holds only the first — `spec/change.md` and
`spec/non-goals.md` as raw blobs, the facts code branches on declared as
`meta` lines (`touches`, `access`, `depends_on`), and everything
retrospective in a commit message body on the item's own ref.

Two orderings are load-bearing and are why this is decomposed rather than
built:

- **The log reader precedes the migration.** The migration moves 28% of
  the board's prose into commit bodies, and no verb reads a commit body
  today. Writing to a place nothing can show is the one ordering that
  must not happen.
- **The pin bump and the migration land back to back.** A format-5 board
  cannot be operated by a clone whose pinned `bin/gitboard` predates it,
  and `_work/format.tl`'s `refusal` accepts exactly one version, so the
  board is unoperable between those two changes.

## Non-goals

Anything the children do not name. In particular this item holds no
code: a change that belongs to the schema arrives as a child with its
own spec, or it is out of scope.

## Access

cosmic-lua/cosmic, read and write on a branch — D47 and D48 live there,
`bin/gitboard.pin` is bumped there, and the sweep of the decision records
is a separate item under another outcome.
