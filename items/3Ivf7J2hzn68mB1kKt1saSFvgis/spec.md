# friction: 2026-09-05 work9c (/work 9 --routine)

## orchestrator

- **goal**: bootstrap, sync, then follow `next`/`take` to find and pull
  the highest-ranked pullable work.
- **actually happened**: opened this log late — after `sync`, `next`,
  and one `spec` write, not before, contrary to friction.md's own
  "opened after the bootstrap and `sync` and before the first verb
  that selects work" rule; caught only while writing this entry.
  Cost: no numbers lost (every board verb up to that point is on the
  git log anyway), but the ordering rule itself was violated once.
- **contributed**: the skill's own bootstrap block doesn't repeat the
  "open the log first" instruction inline — it lives one level up, in
  `skills/work/SKILL.md`'s numbered friction steps, read once at the
  top of the session and easy to let slip once `next`'s answer starts
  driving the next several tool calls.
- **improvement**: doc-level fix only (open the log as literally the
  first scratch-file write in the pass, before the first `bin/gitboard`
  call of any kind, including `sync`) — below the spec bar for a gate,
  so it stays here rather than filed.

- **goal**: pull the highest-ranked pullable item; `next` named
  `refine «sTmy_8tBZ» ... the highest-ranked todo item that misses the
  spec bar`, so refined its `## Change` (added a measured,
  `bin/cosmic`-run reproduction of `max_returns` vs. the proposed
  success-only-arity classifier, and corrected an inexact `qbare`
  analogy to the file's real `%f[%W]` frontier convention), wrote it
  back with `gitboard spec ... --base ...` (`gitboard-spec: 3IkLX2Q4's
  spec replaced`), then re-ran `next` expecting a `pull`.
- **actually happened**: `next` named the SAME refine action on the
  SAME item, verbatim, after the write and after a fresh `sync`. Spent
  ~25 tool calls (git archaeology into `cosmic-lua/work`'s own `main`
  branch — `_work/gitready.tl`, `_work/flow.tl`, `_work/spec.tl`,
  `_work/rank.tl`, `_work/action.tl`, `_work/intake.tl`,
  `_work/gitowner.tl`) plus three standalone Lua harnesses run through
  `bin/cosmic` re-implementing `sections`/`ready_gaps`/`is_ranked`
  against the item's raw `spec.md` blob (`git cat-file -p
  refs/heads/items/<id>:spec.md`) — all of which independently confirm
  `ready_gaps` returns 0 gaps and the item's outcome (`5bUQ_BTyj`, "outcome
  1 of 10") is ranked, i.e. the item SHOULD have read as passing the
  bar — before trying `gitboard take sTmy_8tBZ` directly as a probe,
  which succeeded immediately (`gitboard-take: 3IkLX2Q4 is yours`).
  Wall-clock: this detour was the majority of the pass.
- **contributed**: `bin/gitboard find "0 pullable"`/`"pullable"`,
  which would have surfaced the answer in one call, was tried LAST
  instead of first. It turned up an already-filed, already-diagnosed
  item — «Vahb_Krg9», "gitboard: show/next's pullable count and next's
  recommendation go stale after a spec write clears the bar" — whose
  own `## Evidence` describes this EXACT sequence (spec write clears
  the bar → `show`/`next` still stale → `take` on the same item
  succeeds), first seen in a prior pass's friction log
  (`3IuEiG30`/`friction: 2026-09-05 work9`) and reproduced a second
  time in Vahb_Krg9 itself before this, third time now.
- **improvement**: the fix belongs in `gitboard help orchestrate` or
  `help bar` (already proposed in Vahb_Krg9's own `## Impact`): "after
  writing a spec that should newly pass the bar, probe with `take ID`
  directly rather than trusting the board-overview count or `next`'s
  single recommendation." That's a doc-level change to the tool's own
  help text, not something this pass can land (out of scope: cosmic-lua/work
  source, not cosmic or cosmopolitan). The underlying cache-staleness
  bug is real code work (`_work/cache.tl`/`_work/gitview.tl` vs.
  `_work/gitgate.tl`'s `commit_and_publish` hook) already captured in
  Vahb_Krg9 — not re-filed here to avoid a duplicate; this entry adds a
  third independent repro as corroborating evidence for whoever refines
  it next (its own bar gap is a missing `## Change`).

- **goal**: fill the rest of the wave once one pull was confirmed
  live-but-uncounted.
- **actually happened**: rather than trust `next`'s (stale) single
  recommendation for a second pull, probed `gitboard take jsyr_D5ML`
  directly on the next todo-listed item after visually confirming its
  spec had a `## Change` naming files (`.github/workflows/pr.yml`)
  disjoint from the first item's (`tool/lua/test_definitions_coverage.lua`,
  `tool/net/definitions.lua`). Succeeded on the first try, no detour.
- **contributed**: applying the `take`-is-authoritative workaround
  from the first detour immediately paid for itself on the second
  pull.
- **improvement**: none beyond what's already filed in Vahb_Krg9.

## build sTmy_8tBZ (builder agent) — in flight, not yet reported

Claimed as `build-sTmy_8tBZ-a159f2f2`, branch `3IkLX2Q4` off
`cosmic-lua/cosmopolitan` `master`, worktree
`/tmp/gitboard-worktrees/sTmy_8tBZ`. Spawned in the background; this
pass ends before it reports. Its own `## Friction` section and a
`cosmic _tool/friction.tl` summary of its transcript belong here on
the NEXT pass's reconcile step, once it has a PR or a stopped-short
report.

## build jsyr_D5ML (builder agent) — in flight, not yet reported

Claimed as `build-jsyr_D5ML-a159f2f2`, branch `3IvOr6Gx` off
`cosmic-lua/cosmopolitan` `master`, worktree
`/tmp/gitboard-worktrees/jsyr_D5ML`. Spawned in the background; same
note as above — reconcile next pass.

## candidates

- open the friction log before the FIRST `bin/gitboard` call, not just
  before `next`/`take` — stays here for triage: below the bar for a
  gate, a one-line doc tweak to `skills/work/friction.md`'s own
  "the log" section at most.
- `gitboard help orchestrate`/`help bar` should say outright: after a
  `spec` write meant to clear the bar, verify with `take ID` rather
  than `show`/`next` — stays here for triage: this pass has no
  `cosmic-lua/work` write access scoped for a doc PR against
  gitboard's own source, and the underlying bug is already «Vahb_Krg9»'s
  to fix; a doc-only stopgap on top of an already-filed code fix would
  duplicate effort rather than add it.
