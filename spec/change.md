One test added to `_build/workflows_test.tl` (443 lines; stays under
500):

`test_every_gate_lane_strips_includeif_and_fetches_the_board_ref`:
for every job whose body contains `--make ci` (derive with
`job_body`, over `workflows()`), assert the same job body contains
(a) `git config --local --remove-section "includeIf.gitdir:` — the
strip loop — and (b) `+refs/heads/board:refs/remotes/origin/board` —
the board fetch. Message names the workflow, the job, and which of
the two is missing, and says why: `_build/doc_paths_test.tl` fails
rather than skips under `CI` when `origin/board` is unreadable
(`doc_paths_test.tl:268-282`). Today the set is `pr.yml:ci` and
`release.yml:build`; the test derives it, never lists it, so a third
gate lane inherits the rule.

Mutation: delete `release.yml`'s fetch line → the test fails naming
`release.yml` `build` and the fetch; restore.

Wall: no workflow file changes; `doc_paths_test.tl` unchanged.
Gate: `bin/cosmic --make ci` ends `ci: PASS`.
