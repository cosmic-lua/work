Board-tooling change on the `board` branch of cosmic-lua/cosmic, as a
PR against base `board`, plus one data repair:

1. `_work/gitgate.tl` `ready_problems`: an item's own `repo`, when
   set, must share the board's origin owner (`gh.slug(s, nil)`'s
   owner half) — a foreign owner is refused with a problem naming
   the field, the value, and the repair (`gitboard set ID --repo
   <owner>/<name>`), unless the spec's `## Access` section names that
   exact slug (the deliberate cross-owner case). A board whose origin
   does not resolve to a GitHub slug skips the rule (the local-only
   waiver `handover_refusal` already uses). `take` and `check` report
   it through the existing problem list; no new verb.
2. `_work/gitgraph.tl` (`cmd_new` with `--repo`, and `set --repo`):
   refuse a foreign-owner slug at write time with the same rule and
   the same escape — the spec being written (`--spec-file`) or the
   item's current spec names the slug under `## Access` — so stale
   data stops entering the board. The verdict line names the value
   and the repair.
3. Tests in `_work/gitgate_test.tl` (foreign owner refused; same owner
   accepted; foreign owner declared under `## Access` accepted;
   no-origin board skips) and `_work/gitgraph_test.tl` (`new --repo`
   and `set --repo` refuse a foreign owner, accept with `## Access`).
   Fixture: give the fixture board an `origin` whose `url` is the
   GitHub https form of the board's own slug (`cosmic-lua/cosmic`)
   and whose `pushurl` is the local bare path, so `gh.slug` resolves while `publish` keeps
   pushing locally; add it to `_work/fixture.tl` as an opt-in helper
   so existing fixtures are unchanged. Runner mode; file caps
   (overflow goes in a sibling module).
4. Data repair, separate commit on the board, by the orchestrator
   after the PR lands: `gitboard set ID --repo cosmic-lua/cosmopolitan`
   on the 7 open items above; closed items keep their history.
