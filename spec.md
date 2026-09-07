## Evidence

`_build/casts_baseline.tl` (66 lines) holds per-file cast counts and `docs/design/cast-sites.tsv` (141 rows) holds each cast's kind; `_build/casts.tl` (143 lines), `_build/cast_sites.tl` and `_build/cast_sites_test.tl` (264 lines) maintain them through `_tool/floor.tl` and a `--reconcile` that re-keys rows by `(path, fn, n)` — a scheme that mis-assigned classes on an ordinal shift once already («Infz_bnpL»). `docs/design/casts.md` (491 lines) names 16 kinds as `### ` headings, each with prose and quoted examples; `cut -f5 docs/design/cast-sites.tsv | sort | uniq -c` gives the per-kind counts (34 tl compiler surface … 1 binding constant by name). With «$X as $T» landed, each kind is expressible as a pattern plus a scope: e.g. `tl compiler surface` = `$X as $T` where `$T` renders a `tl.*`/`Node`-field type inside `_types/`, `_build/`, `cosmic/ast/`; `type-defeating test probe` = any cast inside a `*_test.tl`; `map view of a declared value` = `$X as {string: any}` outside tests.

## Change

`_build/casts_test.tl` becomes the ONE file: a list of kinds, each `{name = "tl compiler surface", pattern = "$X as $T:...", where = {"_types/", "_build/", "cosmic/ast/"}, sites = 34}` (pattern and scope written per casts.md's own definition of the kind), and three checks over a fresh `cosmic.ast` walk of the tree: every `as` site matches exactly one kind (a site matching none fails naming `file:line` and the kinds it nearly matched; a site matching two fails naming both), no kind matches more sites than its `sites` count (the shrink-only floor, lowered by hand in the same file), and every kind has at least one site (a kind at 0 is deleted, never kept). `_build/casts_baseline.tl`, `docs/design/cast-sites.tsv`, `_build/cast_sites.tl`, `_build/cast_sites_test.tl`, `_build/casts.tl`'s floor half, and the `_build/casts_baseline.tl merge=union` line go; `docs/design/casts.md`'s Method section describes the allowlist and each `### ` kind quotes its pattern. `_tool/floor.tl` keeps only what `nil_returns` still needs until «nil-flow allowlist» lands, then goes with it.

## Non-goals

No cast is reclassified or removed; the `-- cast: <reason>` marker stays per site (`cast-justify` is unchanged).

## Access

cosmic-lua/cosmic, read and write on a branch; no other repository.

## Ready when

`ls _build/casts_baseline.tl docs/design/cast-sites.tsv` prints nothing, `_build/casts_test.tl` passes with the 16 kinds summing to the tree's cast count, and inserting one unjustified `x as integer` in `cosmic/fs/init.tl` fails it naming that line.
