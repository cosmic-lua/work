- The other 4 sites in the class stay as they are: `cosmic/sandbox/init.tl:205`
  and `cosmic/sandbox/plan.tl:190,241` are a value-FETCH-by-dynamic-name
  shape, not a boolean presence test, and were never what the Goal's
  "boolean presence checks" language described; `cosmic/stream.tl:237`
  casts to a whole reader interface, a third shape again. Folding either
  into `is_present` or inventing a second helper for them is a separate
  item, not this one.
- Do not route any of these 3 sites through `cosmic.check.is_exposed`
  or `cosmic.check.refuses` — `cosmic/check.tl`'s own header rule
  ("never require check from library code") forbids it; `cosmic/sandbox/`
  and `cosmic/quicksand/box/` are library code.
- Do not touch `docs/design/cast-legality.md`. It is a frozen,
  dated census ("Measured against `e0580f41` on 2026-08-31") feeding a
  separate decision (`ke6byr5h`) and says of itself "It decides
  nothing" — it is not a live ratchet `--make ci` checks, and its own
  line numbers for these sites are already stale relative to the
  current tree.
- Do not rewrite the whole `.cosmic-coverage` floor.
