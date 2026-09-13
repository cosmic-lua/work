Re-run the census's Method and take every row under `_eval/` and
`_docs/`. For each, choose between the two mechanisms the census names
— a guard at the site, or an honest signature — and apply it. Record
the choice per file in the PR.

**Measured 2026-08-26** from the committed pre-rules census
(`awk -F'\t' '$1 !~ /_test\.tl$|_example\.tl$|_benchmark\.tl$/ && $1 ~ /^(_eval|_docs)\//' docs/design/nil-flow-sites.tsv`):
**43 rows in 10 files** — `_eval/` 30 rows in 8 files (heaviest
`_eval/checks/json-cli.tl` 8), `_docs/` 13 rows in 2 files. The four
narrowing rules (PR #1383, landed `57dda9bd`) closed part of that;
re-run the scan at pull and write the number into the PR.

These two trees are grouped because both are single-purpose internal
harnesses with few files and dense counts, and because neither is
touched by the other pieces.
