## Evidence

`docs/design/cast-sites.tsv` keys a cast site by `path` and `line`
(`head -1 docs/design/cast-sites.tsv` → `path	line	class`), and
`_build/cast_sites.tl --reconcile` re-derives the line by matching the
committed text (`_build/cast_sites.tl:8-21`). Any edit above a cast
shifts its line and forces the reconcile: `git log --oneline -12 --
docs/design/cast-sites.tsv | wc -l` → 12, and four of today's PRs
(#1759, #1762, #1763, #1765) regenerated the file for line shifts
alone, one builder-gate round each (~2 min and ~3 calls per PR, from
the transcripts). `cosmic.ast` is on main: `o/bin/cosmic --find '$X as $T' cosmic`
does not parse (a cast is not a call), but `cosmic.ast.walk` reaches
every node and tl stamps `kind == "cast"` nodes with `y`/`x`.

## Change

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

## Non-goals

No change to the classes or the justification comments; the nil-returns
and coverage ratchets stay line-based.
