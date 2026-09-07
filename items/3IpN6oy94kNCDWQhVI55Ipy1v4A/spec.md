## Evidence

`_work/doctrine.tl:279` (help orchestrate): "agents never run board
verbs, so no agent needs this worktree or push rights to `board`". The
emitted review brief (`gitboard brief review ID`, "Recording your
verdict" section) instructs the reviewer to run `o/bin/gitboard
verdict ... --session <minted>` from `/home/user/cosmic/o/board`.
Three reviewers did exactly that today (16:28, 17:20-ish,
17:37 verdict commits on the board log), each from the orchestrator's
shared board worktree, while the orchestrator was also committing
there. An orchestrator reading `help orchestrate` first would refuse
to spawn a reviewer with that brief.

**Reconfirmed 2026-09-07, a second session, same conflict from the
other side.** An orchestrator that read `help orchestrate` first (this
one) took its "agents never run board verbs" literally and told every
reviewer, in its own spawn prompt, not to run `gitboard verdict` and
to report the verdict back instead. Every one of 6 reviews spawned
this session (`cBpk_Os62`/PR#1789, `wAe5_evHa`/PR#1791,
`9R8e_zA8Q`/PR#78 rounds 1 and 2, `vGr9_mgmX`/PR#79, `z28g_jVQw`/PR#80)
hit the resulting contradiction: the brief's own "Recording your
verdict" section told the reviewer to run `gitboard verdict`, while
the orchestrator's spawn prompt told it not to. Every reviewer
resolved it the same way (deferred to the orchestrator's instruction,
reported the verdict back in prose) and every one flagged it in its
own Friction section — e.g. "the brief text and the wrapping task
instructions disagree on who records the verdict... the brief itself
should state the no-gitboard constraint when the orchestrator intends
to record verdicts centrally, rather than leaving a subagent to
reconcile two documents." No tool calls were lost (the conflict was
caught before acting, every time), but it's the single most frequent
piece of friction across the whole session — 6 for 6 reviews — and it
runs exactly opposite to this item's own diagnosis: the doctrine text
IS the thing an orchestrator follows, and as long as it says agents
never run board verbs with no exception, an orchestrator will keep
producing this same self-contradictory brief on every review it spawns.

**Separately:** this item's own `repo`/`base` fields
(`cosmic-lua/cosmic`, `board`) target the same stale predecessor branch
`DUkw_bCrv` documents generally — `cosmic-lua/cosmic`'s `board` branch
ships no release; `cosmic-lua/work`'s `main` is the real tree
`_work/doctrine.tl` lives in today. Building this item as currently
specced would repeat exactly the mistake `9R8e_zA8Q`'s original spec
made (landing a real fix on the branch nothing ships from). `repo`/
`base` need correcting to `cosmic-lua/work`/`main` before this is
pulled.

## Change

`_work/doctrine.tl`, the orchestrate topic's first bullet: replace the
absolute with the rule the tool already implements — "agents never
run board verbs, with one exception: a reviewer records its own
`verdict` under the session the orchestrator minted for it, so the log
never shows a builder accepting its own work; every other board move
(take, drop, spec, done) stays the orchestrator's". Add one sentence
on the shared worktree: the verdict verb syncs before it writes, so a
reviewer and the orchestrator committing concurrently is supported;
nothing else should be run there by an agent.

`_work/doctrine_test.tl`: pin the sentence with a `find`.

## Non-goals

No change to the review brief or the verdict verb.

## Access

cosmic-lua/work, read and write on a branch; no other repository. (The
item's `repo`/`base` fields need `set`-ing to `cosmic-lua/work`/`main`
before pulling — see Evidence.)
