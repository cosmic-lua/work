- **Do not change what `merge` DOES.** Scalar-later-wins,
  list-concat-dedupe, map-per-key, unknown-keys-as-scalars, and the
  explicit nil-checked indexing that keeps a stored `false` from
  collapsing to nil (`merge.tl:85-90`) all stay exactly as they are.
  This slice moves types, not behaviour.
- **Do not narrow the schema or make `BoxOptions` closed.** Unknown
  keys must still merge as scalars: the module header calls that "the
  right default for forward-compatible additions", and a policy table
  carrying a field `BoxOptions` does not name must still survive a
  merge.
- **Do not touch `cosmic/sandbox/**`.** Its `merge` is a separate,
  already-typed implementation; it is the precedent to copy, not a file
  to edit.
- **Do not touch the other 7 casts in `cosmic/quicksand/box/init_test.tl`'s
  siblings** or any other `quicksand` file: `run.tl` (2) and the
  remaining `init.tl` casts belong to other classes under the same
  parent.
- **Do not weaken or delete a test assertion.** Casts come out; asserts
  stay.
- **No new `-- cast: from any` anywhere.** The only casts this diff adds
  are the two boundary ones in `merge.tl`, with the reasons named above.
