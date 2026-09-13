- Delete the cast and its `-- cast:` reason at the nine sites; keep
  the surrounding guard comments (`_literal_lex.tl:214-222`'s BOUNDED
  note stays — the bound is the code, not the cast).
- `_build/casts_baseline.tl`: `cosmic/format/init.tl` 5 → 1,
  `cosmic/_literal_lex.tl` 3 → gone, `cosmic/fs/octal.tl` 1 → gone,
  `cosmic/url.tl` 1 → gone (`bin/cosmic --make run _build/casts.tl --baseline`).
- `docs/design/cast-sites.tsv`: `bin/cosmic --make run _build/cast_sites.tl --reconcile`;
  the class empties, so delete `### numeric narrowing` (`casts.md:261-277`)
  and every prose mention (`git grep -n "numeric narrowing" origin/main -- docs _build`;
  `cast-legality.md` is a dated census and keeps its row).
- `bin/cosmic --make ci` ends `ci: PASS`; `_build/coldbuild_test.tl`
  is the proof the pinned checker accepts the result.
