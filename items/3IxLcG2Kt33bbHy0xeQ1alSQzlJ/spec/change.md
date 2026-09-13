`skills/work/SKILL.md` (or `gitboard help orchestrate`/`help build`,
whichever already documents the builder/orchestrator division of
labor) should state as a hard rule, not a preference: **a spawned
agent (builder, research, review) never polls and never subscribes to
external events — including GitHub's own** (no repeated "check again"
turns, no `subscribe_pr_activity`, no watching a workflow run or a
release publish itself). A step that depends on slow-to-settle
external state beyond the item's own PR/CI gate (triggering and
awaiting a separate workflow run, a release publish, another team's
webhook, GitHub Actions completion, etc.) is the ORCHESTRATOR's job,
full stop — cheap, targeted API or CLI checks, or (for genuinely
long waits) `ScheduleWakeup`/a scheduled check-in — and the spawned
agent is only invoked (fresh, or resumed) once that external state has
already changed and there is real work for it to do next.

The subscribe case is not just wasteful the way polling is — it is
actively broken: a webhook fires into whichever session holds the
subscription, and a spawned builder/research/review agent's session
ends when it returns its final report. A GitHub event delivered after
that point has nothing live to wake, so a subagent that subscribes to
"be notified when this PR's CI finishes" is subscribing on behalf of a
session that will already be gone. Only the orchestrator's own
(persistent, resumable) session may hold a PR/event subscription.

A builder or research brief for an item shaped like this should say so
directly: "the orchestrator will trigger/monitor the external process
and resume you only once it completes — do not poll, and do not
subscribe to any event yourself." Whoever refines this into the actual
doc/skill edit should also check whether `gitboard brief`'s own
templates should carry this line structurally, so it reaches every
brief this shape applies to rather than depending on each hand-written
prompt to remember it.
