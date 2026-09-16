Measured 2026-09-16 across one orchestrator pass working the top-10
token-efficiency list. Six distinct instances of the tool's own prose naming
mechanics the tool no longer has, each found by being refused:

1. `skills/work/SKILL.md` says the friction ask must be appended to every
   spawned agent's prompt by hand "until `gitboard brief` carries it".
   `brief` already carries it — line 202 of every emitted builder brief.

2. `skills/work/SKILL.md`'s bootstrap fetches `refs/heads/state` and
   `refs/heads/board/format` only. That is enough to READ the board and not
   to write to it: the first `claim` refused with `archive: refs/heads/
   claim-batches not fetched — 542 of 542 witness refs absent locally`, then
   `ended` (723), then `items` (725), then `removed refs/heads/board/seq`.
   Four serial refusals, one per attempt.

3. `skills/work/friction.md`'s closing procedure says to file each
   countermeasure `gitboard new "<title>" --parent <goal> --spec-file <spec>`
   "with the log's entry as its Evidence". Refused:
   `REFUSED: Evidence is not a spec section — a measurement or a narrative is
   a log entry: gitboard log ID --add FILE`.

4. `gitboard help orchestrate` describes the review path as "one fresh
   subagent per handed-over commit ... each claimed first with its own minted
   session", which reads as `claim`. `claim` refuses — the builder's claim is
   still held. The verb is `handoff`, which drops, re-claims, checks out and
   briefs in one. Board item «9cnW_GG8u» is the same observation.

5. `gitboard help orchestrate`'s review recipe never names
   `--gitboard-command`/`--gitboard-cwd`, so the default review brief emits
   the literal `GITBOARD-INVOCATION-UNRESOLVED-ASK-THE-CALLER` as its
   invocation line. A reviewer this pass could not record its own verdict:
   it found a working `o/bin/gitboard` in its own warm worktree and correctly
   declined to use it, because the brief forbids a self-bootstrapped
   substitute. Passing the two flags on the next handoff fixed it completely
   (`grep -c GITBOARD-INVOCATION-UNRESOLVED` → 0), so the flags work; knowing
   to pass them is the whole gap.

6. `gitboard help done` lists `--dir`, `--reason`, `--by`, `-h`. Ending an
   accepted item refuses with `REFUSED: completed accepted work names its
   landed commit with --landed` — a flag the help does not mention.

Aggregate cost in this pass: roughly 15 orchestrator tool calls, plus one
reviewer unable to complete its single deliverable.

What is NOT wrong: every one of these refusals names its own fix, which is
why each cost one to three calls rather than a cycle, and why none produced
wrong work. The refusal text in this tool is a model of the form. The defect
is that a reader cannot trust a help page or a skill file without testing it
against the binary, and six instances in one pass is a missing gate rather
than six mistakes.