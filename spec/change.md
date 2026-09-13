Re-run the census's Method and take every row under `cosmic/fs/`.
For each, choose between the two mechanisms the census names — a guard
at the site, or an honest signature — and apply it. Record the choice
per file in the PR.

**Measured 2026-08-26** from the committed pre-rules census
(`awk -F'\t' '$1 !~ /_test\.tl$|_example\.tl$|_benchmark\.tl$/ && $1 ~ /^cosmic\/fs\//' docs/design/nil-flow-sites.tsv`):
**39 rows in 5 files** — `cosmic/fs/tree.tl` 10, `cosmic/fs/find.tl` 8,
`cosmic/fs/walk.tl` 7, `cosmic/fs/path.tl` 6, and the remainder. The
four narrowing rules (PR #1383, landed `57dda9bd`) closed part of that;
the post-rules count is smaller and the scan is the authority — re-run
it at pull and write the number into the PR.

This is the densest piece and the one whose types are most-used: `fs`
is the published API a `cosmic` script reaches for first, so a lie here
is the one G3's "types never lie" promise is about.
