- Not the `math.type(x) == "integer"` narrowing entry, and not the
  tree-wide census or `docs/design/integer-strictness.md` — both stay
  `MVs4_UosO`'s scope (or a re-filed successor); bundling them here
  would be exactly the "and" the sizing rule says to cut apart, and
  neither depends on this patch or is depended on by it.
- Not touching `narrowed_declaration`'s general behavior: the gate
  checks `declared_t.typename == "number"` and the narrowed
  `t.typename == "integer"` by exact typename, so record/interface
  narrowing (`local x: Base = Derived()`) and every other narrowed
  type pair is untouched — verified by construction (the typename
  check), not just by intent.
- Not extending the gate to a type ALIAS of `number` (`type Meters =
  number`) or to a `number`-containing union declaration — only a
  bare `number`-typed declaration is covered, matching exactly what
  was measured in this pass. Widening to aliases is unmeasured and
  left for a follow-up if it turns out to matter.
- Not un-gating `COSMIC_INTEGER_STRICT` by default, and no
  `bin/cosmic.pin` bump — a gated, off-by-default patch changes no
  in-tree result (confirmed: `--make ci` gate-off is unaffected), so
  neither applies.
