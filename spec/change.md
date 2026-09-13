`_work/gh.tl`: one function `head_checks(repo, pr): "green" | "red" |
"running" | "none", string` over the PR head's check runs (the same
read `verdict` uses; `none` when a repo runs no checks).
`_work/gitverbs.tl`, the review claim in `take`: refuse with
`gitboard-take: REFUSED: <id>'s head <sha7> has CI running (<n> of <m>
checks done) — review when it settles` unless `--force`. `next`
(`_work/action.tl`): a reviewable item whose head is `running` is
rendered `ci running` under doing and not offered as head; `red`
renders as `ci red — builder's` and is also not offered. `brief
review`: fill `<HEAD_SHA>` from the same read when the state is
`green`, and refuse to emit for `running`/`red` with the same verdict
line. Off-line (no GitHub reach) every path behaves as today.

`_work/gitverbs_test.tl`, `action_test.tl`, `brief_test.tl`: a fixture
PR in each of the four states.
