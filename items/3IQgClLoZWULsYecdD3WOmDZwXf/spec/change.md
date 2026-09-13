Re-run the census's Method and take every row under `cosmic/` that is
NOT under `cosmic/fs/` and NOT `cosmic/time.tl`. For each, choose
between the two mechanisms the census names — a guard at the site, or
an honest signature — and apply it. Record the choice per file in the
PR.

**Measured 2026-08-26** from the committed pre-rules census
(`awk -F'\t' '$1 !~ /_test\.tl$|_example\.tl$|_benchmark\.tl$/ && $1 ~ /^cosmic\// && $1 !~ /^cosmic\/fs\//' docs/design/nil-flow-sites.tsv`):
**50 rows in 31 files**, of which `cosmic/time.tl`'s 7 belong to
3IPXQcgW — so **43 rows in 30 files** here. Thin and wide, unlike the
`fs` piece: most files carry one or two. The four narrowing rules
(PR #1383, landed `57dda9bd`) closed part of that; re-run the scan at
pull for the current count and write it into the PR.

If the post-rules count is still past one session's diff, this item
becomes a container: file file-disjoint children under it by module
group rather than stretching one PR across 30 files.
