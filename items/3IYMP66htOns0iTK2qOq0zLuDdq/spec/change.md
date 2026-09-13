- `_make/policy.tl`: add and export on `PolicyModule`
  `must_verb(by_name: function(string): Verb | nil, name: string): Verb`:
  `local v = by_name(name)`, then
  `assert(v, "make: no verb " .. name) -- assert: the registry is literal data in _make/init.tl and every name passed here is a row it defines`
  (D30's infallible-by-type contract boundary; the trailing `-- assert:`
  satisfies `assert-justify`), `return v`.
- `_make/init.tl`: at the seven lines above replace
  `by_name("<x>") as Verb -- cast: …` with `policy.must_verb(by_name, "<x>")`.
  Net line count must stay ≤ 500 (`wc -l`); the replacement removes no
  lines and adds none.
- `_build/casts_baseline.tl`: `_make/init.tl` row 7 → gone; run
  `bin/cosmic --make run _build/casts.tl --baseline` and commit.
- `docs/design/cast-sites.tsv`: run `bin/cosmic --make run
  _build/cast_sites.tl --reconcile`. This drops only the 7
  `_make/init.tl` rows; the `cosmic/searcher_test.tl	58` row survives
  (it is `zs1K_cWnY`'s, untouched here), so the `dynamic name lookup`
  class ends this item with exactly 1 row, and
  `_build/cast_sites_test.tl`'s every-heading-has-a-row check still
  passes without a section deletion. Do not delete
  `docs/design/casts.md`'s `### dynamic name lookup` section here —
  it still has a live row.
- `docs/design/casts.md:274-275`: repoint ONLY the fenced citation's
  header and quoted line — nothing else in the section — from

  ```text
  -- _make/init.tl:143
    local v = by_name("build") as Verb -- cast: the registry defines it
  ```

  to

  ```text
  -- cosmic/searcher_test.tl:58
    local ok, why = pcall((s as function(string): any), missing)
  ```

  Leave every other line of the section (the class description above
  the fence and the entire "What closes it here" paragraph below it,
  including its stale "wants a declared record" sentence) byte-for-byte
  unchanged — that paragraph is `zs1K_cWnY`'s to rewrite, not this
  item's.
- `bin/cosmic --make ci` ends `ci: PASS`.
