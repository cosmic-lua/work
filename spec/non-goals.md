- No new type declarations anywhere — this group exists because every
  needed type already does.
- No behavior change beyond `headers.tl`'s stated `tostring` fallback
  for contract-violating header values; every guard keeps its runtime
  semantics (`is {K: V}` compiles to the same `type(x) == "table"`
  test the code already ran).
- Do not chase the `metatable<any>` checker limitation here — if it
  deserves closing, that is a tl-patch capture, not this diff.
- Do not touch the other 7 sites of the parent's 16-site residue; they
  are the sibling slices'.
- `deep_equal`'s semantics (`==` first, then structural) are frozen —
  test helpers across the tree depend on them.
