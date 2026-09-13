Board-tooling change on the `board` branch of cosmic-lua/cosmic, as a
PR against base `board`, one handover for research mirroring the PR
one:

1. `_work/item.tl`: a `result: string` field — the sha256 of the spec
   sidecar at handover (the same digest `verdict_spec` records), empty
   when unset. `problems` reports an item carrying both `pr ~= 0` and
   `result ~= ""` (a deliverable is a diff or board state, never
   both), and `result` on an item with no `builders` (a handover with
   no work).
2. `_work/gitverbs.tl` (`take`): `take ID --result` records the
   handover — refused unless the caller holds the live claim (same
   rule as `--pr`), refused when `pr ~= 0`; it stores the current
   spec's digest and clears any standing `verdict` the way `--pr`
   re-opens one for a new head. `take ID --pr N` on an item with
   `result` set is refused symmetrically.
3. `_work/flow.tl` `substate`: `result ~= ""` ranks as "review"
   exactly as `pr ~= 0` does, so `next`'s review rung, the take gate
   ("diff(s) await a verdict") and `show` all see it — one change at
   the one declaration, no reader edited.
4. `_work/brief.tl` + `_work/brieftext.tl`: `brief review` accepts an
   item with `result ~= ""` and emits a `RESEARCH_REVIEW` template —
   the spec verbatim, no PR/diff to fetch, the instruction to re-run
   every probe the spec records and to judge the spec revision and
   the captures it names (`new`/`attach`/`block` landed on the board),
   and the same verdict command without `--pr`/`--head`. The
   PR-based `REVIEW` template is untouched.
5. `_work/gitverdict.tl`: for an item with `result ~= ""`, refuse when
   the spec's current digest differs from `result` (the spec moved
   after handover — hand it over again), the same shape as the
   head-moved refusal for PRs; otherwise the existing PR-less path
   records `verdict_spec` as today.
6. Tests: `_work/gitverbs_test.tl` (take `--result` accepts on a live
   claim, refuses without one and with a PR; `--pr` refuses with a
   result), `_work/flow_test.tl` (substate review for a result
   item), `_work/action_test.tl` (next offers the review ahead of a
   todo pull), `_work/gitverdict_test.tl` (spec-moved refusal),
   `_work/item_test.tl` (both problems), plus a `brief review` case
   on a result item. Runner mode. `help take`, `help verdict` and the
   doctrine's review/orchestrate lines that describe the research
   handover name `take ID --result` where they now say "leaves the
   item claimed and PR-less".
