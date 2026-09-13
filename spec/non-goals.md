- **Do not generalize `shape.map`.** Its signature, its `"expected map,
  got a non-string key"` message and its `Spec` shape are unmoved.
- **Do not add any other key kind** — no number-, boolean- or
  arbitrary-key combinator, and no `shape.equal`.
- **Do not change any semantics D28 froze**: extra keys stay ignored,
  nothing is coerced, errors stay plain strings carrying the first
  mismatch, and `into` still returns the same table it was given.
- **Do not change `read_cov`'s signature, its three error strings, or
  the `.cov` file format**, and do not touch `cosmic.literal`'s grammar
  — integer bracket keys there are board item 3IOGXIBq.
- **Do not edit `docs/design/casts.md`.** It declares itself measured at
  `d3e59de7` (`docs/design/casts.md:10`) and its counts describe that
  commit; the `doc-citation` lint treats it as a snapshot and repointing
  it is not this slice's business.
- **Do not close any other `from any` cast.** The other 96 are their own
  board items.
- **Do not supersede D28** or open a new decision record.
