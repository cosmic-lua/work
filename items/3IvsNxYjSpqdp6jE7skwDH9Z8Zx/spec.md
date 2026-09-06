# friction: 2026-09-06 work9 (/work 9 --routine)

## orchestrator

- **goal**: open the friction log as the first scratch-file write of
  the pass, before the first `bin/gitboard` call, per
  `skills/work/friction.md`.
- **actually happened**: ran `git status`/`sync`/`show`/`next`/`take`
  for the first two claims before writing anything to this log —
  caught only while filing it at the end of the pass.
- **contributed**: this is at least the third occurrence of the exact
  same slip (see `saSF_vgis`, "friction: 2026-09-05 work9c", which
  itself names the same failure and proposes the same fix). The
  bootstrap block in `skills/work/SKILL.md` names the rule once, at
  the top; nothing at the point where a fresh pass actually starts
  moving (right after `sync`) re-surfaces it.
- **improvement**: same fix `saSF_vgis` already proposed, still
  unapplied: create the friction scratch file as literally the first
  action of the pass, before `sync`. Below the spec bar for a gate on
  its own; a third independent repro is added here as corroborating
  weight for whoever eventually turns this into a doc fix.

- **goal**: spawn the first builder agent (`GLwD_dfBT`) into the
  worktree the orchestrator itself had just created at
  `/home/user/wt/GLwD_dfBT`, per `help orchestrate`'s "one fresh
  worktree per agent, on the branch `take` names".
- **actually happened**: passed `isolation: "worktree"` to the Agent
  tool on the first spawn — a harness feature that creates ANOTHER,
  separate worktree of its own choosing, unrelated to the one already
  prepared and named in the prompt. Caught immediately from the tool
  result's shape (no confirmation the agent's cwd matched the
  intended path); stopped the agent via `TaskStop` before it did any
  work and re-spawned without `isolation`, this time cd'ing into the
  path explicitly in the prompt. Cost: one wasted launch + stop cycle,
  ~3 tool calls, no lost work (`git worktree list` confirmed no stray
  worktree was left behind).
- **contributed**: the Agent tool's own `isolation: "worktree"` option
  and gitboard's own worktree convention are two independent
  mechanisms for the same concept, and nothing in `help orchestrate`
  or the builder brief warns that the two must not both be used —
  reading the Agent tool's schema in isolation, `isolation: "worktree"`
  looks like the right way to hand a subagent its own checkout.
- **improvement**: `help orchestrate`'s worktree bullet could say
  outright: "create the worktree yourself with `git worktree add` and
  pass its path in the prompt; never pass the Agent tool's own
  `isolation: worktree` option for a gitboard-claimed item — it
  creates an unrelated worktree, not the one `take` named."

- **goal**: fill a 9-wide wave with disjoint todo items, using each
  item's `overlaps:` annotations (shown by `show`) to judge
  disjointness against the wave already claimed.
- **actually happened**: `overlaps:` on an item only lists that
  item's overlaps against OTHER TODO ITEMS in general — it does not
  know which items THIS session has claimed so far in the pass, so
  every candidate needed its own `show ID` read and a manual
  file-list cross-check against the wave's already-claimed items
  (e.g. confirming `W3uo_Bvcn`'s new `tool/lua/BUILD.mk` hunk near its
  `MODE=cov` block and `A5NT_ilwk`'s comment edit near
  `TOOL_LUA_LUA_MODULES` don't share a hunk, before deciding to skip
  `A5NT_ilwk` from this wave anyway out of caution). Roughly 10
  `show` calls to seat 5 builders; three well-specified but
  higher-risk items (`rLV8_r8a5`, `zs1K_cWnY`, `55xy_ILjS` — tl
  checker-patch internals, a multi-item pin-bump chain, and a
  spec-editing research slice respectively) were read in full and
  deliberately left for a pass with more budget to work through
  carefully rather than risk a bad parallel build.
- **contributed**: no tool gap here — the overlap field is inherently
  pairwise-static (computed at write/refine time between existing
  todo items), and a live wave is a moving target no static field can
  track. This is an inherent cost of manual disjointness-by-reading,
  not a bug.
- **improvement**: none filed — `help orchestrate` already places
  this judgment on the orchestrator ("Disjoint or not at all... judged
  on the MERGE... your check"), and no tool change would remove the
  need to read the spec.

## build GLwD_dfBT (builder agent) — in flight, not yet reported

Claimed as `build-GLwD_dfBT-8bf1d440`, branch `3IvmV3Rk` off
`cosmic-lua/cosmopolitan` `master`, worktree
`/home/user/wt/GLwD_dfBT`. Spawned in the background; this pass ends
before it reports. Its own `## Friction` section belongs here on the
next pass's reconcile step.

## build W3uo_Bvcn (builder agent) — in flight, not yet reported

Claimed as `build-W3uo_Bvcn-8bf1d440`, branch `3IvOz0wC` off
`cosmic-lua/cosmopolitan` `master`, worktree
`/home/user/wt/W3uo_Bvcn`. Spawned in the background; same note as
above — reconcile next pass.

## build bj12_PZHY (builder agent) — in flight, not yet reported

Claimed as `build-bj12_PZHY-8bf1d440`, branch `3IlWcRWI` off
`cosmic-lua/cosmic` `main`, worktree `/home/user/wt/bj12_PZHY`.
Spawned in the background; same note as above — reconcile next pass.

## build MVs4_UosO (builder agent) — in flight, not yet reported

Claimed as `build-MVs4_UosO-8bf1d440`, branch `3Ip92R4r` off
`cosmic-lua/cosmic` `main`, worktree `/home/user/wt/MVs4_UosO`.
Spawned in the background; same note as above — reconcile next pass.

## build Sv9x_dXyj (builder agent) — in flight, not yet reported

Claimed as `build-Sv9x_dXyj-8bf1d440`, branch `3ItrqJui` off
`cosmic-lua/cosmic` `main`, worktree `/home/user/wt/Sv9x_dXyj`.
Spawned in the background; same note as above — reconcile next pass.

## candidates

- open the friction scratch file as literally the first action of a
  pass, before `sync` — stays here for triage: a doc-only fix to
  `skills/work/SKILL.md` or `skills/work/friction.md`, and this is
  now the third independent repro (after `3IuEiG30`/`work9` and
  `saSF_vgis`/`work9c`) without the fix having landed yet.
- `help orchestrate`'s worktree bullet should warn against the Agent
  tool's own `isolation: worktree` option for a gitboard-claimed item
  — stays here for triage: a doc-only addition to `help orchestrate`,
  out of scope for a `cosmic`/`cosmopolitan` PR (it is
  `cosmic-lua/work`'s own source), one occurrence so far.
