`bin/cosmic --make coverage --min PCT [--min-file PCT]`: the stage
computes overall line coverage and per-file coverage from the same
`.cov` data it reads today and refuses when the overall figure is under
`--min` or any file's figure is under `--min-file`, naming each file
under the floor with its percentage; with neither option the stage
reports and passes. `.cosmic-coverage`, `_tool/coverage/baseline.tl`'s
ratchet (`check`, `gate`, `safer_floor`, `newrows.tl`) and the
`--baseline` verb are removed; `embed/cosmic.mk`'s `ci` recipe passes
the two numbers measured on main at pull time (overall from
`o/coverage-summary.txt`; per-file = the current lowest row's
percentage, rounded down to a whole number) so the tree's own gate
holds exactly today's floor on day one. `_tool/coverage/baseline_test.tl`
becomes `_tool/coverage/minimum_test.tl`: a corpus at 80% passes
`--min 80` and fails `--min 81`; one file at 50% fails `--min-file 60`
naming it. `docs/decisions/d27-one-committed-floor.md` and
`d06-defaults-plus-ratchets.md` are amended by the `decide` skill's
form: the coverage floor is an option, not a file; AGENTS.md's Testing
paragraph on `.cosmic-coverage` is replaced by the two-option sentence.
