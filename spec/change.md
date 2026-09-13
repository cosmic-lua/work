In every `*_test.tl` under this batch's scope — testdata excluded,
`_tool/seam_test.tl` excluded — delete each line matching exactly
`^test_[A-Za-z0-9_]*()$`: a bare call at column 1, no arguments.
Then hand-edit `_tool/seam_test.tl`: delete its four real self-call
lines (named in Evidence), leaving the `test_addition()` line inside
`LEGACY_SRC`'s long bracket untouched. Nothing else changes in those
files, and no file outside the scope is touched.

The mechanical half, run from the repo root and kept OUT of the tree
(a `*.tl` inside it joins the build graph):

```
grep -rln '^test_[A-Za-z0-9_]*()$' --include='*_test.tl' _build _docs _types 3p _fuzz _eval _perf _tool | grep -v /testdata/ | grep -v '^_tool/seam_test.tl$' | xargs sed -i -E '/^test_[A-Za-z0-9_]*\(\)$/d'
```

If a ratchet gate complains, run exactly the regen command its failure
message prints and commit the result — never weaken a gate another
way.
