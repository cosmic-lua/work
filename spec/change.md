Re-run the census's Method and take every row under `_perf/`, `_cli/`,
`_tool/`, `_make/`, `_build/` and `cmd/`. For each, choose between the
two mechanisms the census names — a guard at the site, or an honest
signature — and apply it. Record the choice per file in the PR.

**Measured 2026-08-26** from the committed pre-rules census
(`awk -F'\t' '$1 !~ /_test\.tl$|_example\.tl$|_benchmark\.tl$/ && $1 ~ /^(_perf|_cli|_tool|_make|_build|cmd)\//' docs/design/nil-flow-sites.tsv`):
**47 rows in 25 files** — `_perf/` 12 in 8, `_cli/` 11 in 4, `_tool/`
10 in 4, `_make/` 8 in 5, `_build/` 3 in 2, `cmd/` 3 in 2. The four
narrowing rules (PR #1383, landed `57dda9bd`) closed part of that;
re-run the scan at pull and write the number into the PR.

The repo's own toolchain, grouped as one piece: no published API, and
`_cli/`, `_make/` and `_tool/` are the trees a `--make` change already
touches together, so keeping them in one diff is what keeps them
disjoint from everything else.
