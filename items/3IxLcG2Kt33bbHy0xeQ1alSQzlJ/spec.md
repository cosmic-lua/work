## Evidence

Board item `q1bW_VFz2` (bump `bin/cosmic.pin` to a release carrying a
merged checker fix) needed to: trigger `cosmic-lua/cosmic`'s
`release.yml` via `workflow_dispatch`, wait for it to publish, then
download/verify/edit/gate/push/PR. The spawned builder agent
(`build-q1bW_VFz2-748ecc95`, this session, 2026-09-06) triggered the
workflow correctly on its first attempt, then reported "still
building" (or equivalent) across five separate resumes before the
orchestrator gave up resuming it and did the remaining work directly.

Each resume cost ~69k-94k cache-read input tokens (the agent's full
prior context reloaded) to produce, in every case, the same
"still waiting" conclusion — roughly 350k+ tokens total spent
confirming nothing had changed. The orchestrator's own direct checks
of the same external state (`mcp__github__actions_get`
`get_workflow_run`, `list_workflow_jobs`, `list_releases`) cost 2-3
tool calls each, near-zero by comparison, because the orchestrator
does not reload a full subagent transcript to make one API call.

Once the orchestrator found the release had actually published (after
the agent's fifth "still waiting"), it completed the ENTIRE remaining
task itself — download, sha256 verify against `SHA256SUMS`, edit
`bin/cosmic.pin`, a genuinely cold `rm -rf o && --make fetch &&
--make ci` (289 checks, 3342 tests, green), commit, push, open PR
#1748 — in about the same handful of tool calls as ONE of the
builder's wasted resumes.

## Root cause

A spawned subagent has no durable way to wait on external state across
its own turns. Unlike the orchestrator (which has `ScheduleWakeup`/
`Monitor` specifically for polling external, harness-untracked state
at a matched cadence), a builder or research agent that hits a step
depending on slow external state (a CI run, a workflow dispatch, a
release publish) can only end its turn and hope a human or the
orchestrator resumes it — and each resume re-loads its entire prior
context at full cost, whether or not anything changed.

## Change

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

## Non-goals

Not proposing a new tool or capability for subagents to self-schedule
wakeups — that infrastructure question is out of this item's scope,
and the ban above makes it moot for GitHub events specifically: a
subagent is never the right place for that subscription regardless of
what wakeup mechanism it might someday have. This is a documentation/
process fix: state the existing division of labor (orchestrator polls
or subscribes, agent acts) explicitly and as a hard rule for this
specific failure mode, so a future orchestrator session doesn't repeat
the same five-times-expensive pattern this pass did, and no session
ever spawns an agent that subscribes to a PR on its own.
