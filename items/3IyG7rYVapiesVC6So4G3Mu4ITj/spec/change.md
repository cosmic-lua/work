`_build/cast_sites.tl`: key a site by `(path, enclosing function name,
ordinal of the cast within that function, cast text)` instead of
`(path, line)`, derived by walking the file with `cosmic.ast.walk`
(kind `cast`, its `e1`/`casttype` text, the nearest enclosing
`local_function`/`global_function`/`record_function` name, `<chunk>` at
top level). `docs/design/cast-sites.tsv` columns become
`path	fn	n	cast	class`; `--reconcile` rewrites the file once from
the current tree (same classes carried by `(path, fn, n)`), and after
that a line shift changes nothing. `_build/cast_sites_test.tl`: a
fixture with two casts in one function, an inserted line above them →
the key is unchanged; a cast moved to another function → a finding
naming both keys. `_build/casts_baseline.tl` counts stay per path.
