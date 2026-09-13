In exactly these 5 files, delete each line matching exactly
`^test_[A-Za-z0-9_]*()$` — a bare call at column 1, no arguments:

```
grep -l '^test_[A-Za-z0-9_]*()$' _build/cast_sites_test.tl _build/nil_returns_test.tl _perf/baserun_test.tl _perf/skew_test.tl _perf/tiebreak_test.tl | xargs sed -i -E '/^test_[A-Za-z0-9_]*\(\)$/d'
```

Nothing else changes in those files, and no file outside this list is
touched. If a ratchet gate complains (none is expected per the Evidence
above, but if the tree has moved), run exactly the regen command its
failure message prints and commit the result — never weaken a gate
another way.
