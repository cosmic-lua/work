## Evidence

Three gates commit a tracking file the build reads back
(D27): `.cosmic-coverage` (309 rows; `git log --oneline -30 --
.cosmic-coverage | wc -l` → 18 of the last 30 commits touched it),
`_build/casts_baseline.tl` + `docs/design/cast-sites.tsv` (regenerated
12 times; 4 of today's PRs for line shifts), and
`_build/public_surface_baseline.tl`. Every PR that adds a file or moves
a line pays a row edit, and the coverage rows are environment-sensitive
(`cosmic/coverage/SENSITIVITY.md`; `--baseline` refuses outside CI),
so a builder hand-edits a pair it cannot measure locally — three of
today's 13 builders lost a gate round to it. The expectation the rows
encode is simpler than the rows: a minimum coverage, overall and per
file, and a maximum file length — each a number the command line can
carry.

## Change

The goal owner's direction (2026-09-06): the gates assert their
expectation as command-line options, and the committed tracking files
go. Children: coverage minimums replace `.cosmic-coverage`; the file
cap becomes an option; cast sites keyed by AST node («G3Mu_4ITj»)
answers the third file. Each child amends the decision it touches
(D06 defaults-plus-ratchets, D27 one-committed-floor, D39 the file
cap) through the `decide` skill in the same PR — the record's `status`
moves, the index derives.

## Non-goals

No change to what the coverage stage measures; no change to the
example or doc ratchets.
