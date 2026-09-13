Revised per board item `3ImmKYCJ`'s decision (2026-09-03), superseding
the blanket-retype approach described in the rejected-PR note above.

Split the two purposes these iterators currently overload onto one
`__call` signature, instead of retyping that one signature to cover
both:

1. **The `for … in` call** keeps its existing calling convention
   (`iter()`, called by the for-in protocol) and its first return is
   retyped to plain, non-nilable `string` — this closes the seven
   census rows above exactly as the original Change intended.
2. **The terminating payload** (the subtree-error list, the
   read-failure message) moves to a NEW, separate accessor with its
   own honestly-nilable/typed signature, called once after the loop
   ends — never by calling the iterator again.

The concrete shape differs per iterator; do this per-iterator, not
uniformly:

- **`FileIter`** (`cosmic/fs/find.tl:107-113`): already a record
  with a `__call` metamethod and an existing `close` method — already
  an object. Add a new method (e.g. `errors(self: FileIter):
  {string}` — exact name is this build's own naming call, per D20)
  returning the trailing subtree-error list. Retype
  `metamethod __call` to `function(self: FileIter): string`.
  Migrate `cosmic/fs/find.tl:123-125`'s documented direct-call
  pattern (and its docstring, and the stale copy at `:271-274`) from
  `local _, errs = iter()` to the new accessor call.
- **`stream.LineIter` / `Body.lines()`** (`cosmic/stream.tl:56`,
  `cosmic/fetch/body.tl:137` — `Body:lines()` returns exactly
  `stream_mod.lines(self)`, so fixing `stream.LineIter` fixes both):
  currently a BARE FUNCTION type
  (`type LineIter = function(): string | nil, string`), not a table
  — there is nothing to hang a second accessor on today. Promote
  `LineIter` to a callable record: a `__call` metamethod (retyped to
  plain `string`) plus a new method exposing the terminal
  read-failure message. This is a real shape change — every existing
  holder of a `LineIter`-typed value needs to keep working against
  the new record shape, not just the two direct-call sites named
  above; audit for others during the build (grep `LineIter`,
  `stream.lines`, `:lines()` across `cosmic/`).

Then drop the corresponding `check.must(<var>)` wraps in whichever
sweep children have landed (or leave them; they are harmless). A
public-API type AND shape change (LineIter goes from function to
record): name it plainly in the PR and in the module docs.
