`_work/gitview.tl`'s `cmd_next`: build a `CiStates` map the same shape
`action.tl` expects, by calling `gh.head_checks` once per
`STAGE_REVIEW` item that carries a `pr` field (mirroring the existing
`claim_ages` live-read pattern for staleness), and pass it through to
`next_action`/`phased_action`. Off-line (no GitHub reach) `head_checks`
already returns `nil` per call per «FacE_b8sh»'s Evidence, and every
degrades-to-today's-behavior guarantee that item already tested at the
`action.tl` layer should hold unchanged through this wiring — add
one integration-level test in `_work/gitview_test.tl` (or a sibling,
if that file is near its own 500-line cap — check first) confirming a
live `next` actually renders "ci running"/"ci red — builder's" for a
fixture PR in those states, not just that `action.tl` can.
