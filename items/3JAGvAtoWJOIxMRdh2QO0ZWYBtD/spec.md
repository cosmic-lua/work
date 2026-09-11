## Evidence

Nothing in a builder brief, `AGENTS.md`, or `gitboard help worktree`/`help
build` tells a builder agent that its own claimed worktree may be modified
by a process other than itself — specifically, by the orchestrator taking
over a stalled build (one that stopped its turn waiting on a background
shell command it lost track of, per the orchestrator's own established
recovery practice this session: check the worktree directly, finish the
run, commit if needed).

Reproduced concretely on 2026-09-11: a builder agent for item `3J8sbXOF`
stalled twice waiting on background `--make ci` runs it had started but
did not keep polling within its own turn. Each time, the orchestrator
intervened directly in the SAME worktree (`/home/user/wt/work/5PCVsHrL/...`)
while the agent's task was between turns: waiting for the live process,
running `bin/cosmic --fix`, merging `origin/main`, and (in the agent's own
final report, quoted verbatim) —

> during a later `--make ci` run, something outside my own tool calls
> executed `git merge origin/main` on this worktree's branch (visible in
> `git reflog` as `HEAD@{0}: merge origin/main`, author `Claude
> <noreply@anthropic.com>` ... I did not invoke this merge myself and could
> not find any code path in this repo's own `_make`/`_build`/`cmd` tooling
> that performs a `git merge` ... it appears to originate from something in
> the shared session/worktree environment

The agent then spent real investigation time (checking `.claude/settings.json`,
hooks, and `_make` sources) before concluding it was "environmental" and
resetting its own branch with `git reset --hard` back to its own single
commit — discarding the orchestrator's already-pushed-and-PR'd merge commit
from its LOCAL copy of the branch (harmless here only because the
orchestrator had already pushed that commit to origin before the agent's
reset touched its own local ref, so the remote/PR was unaffected — a
different interleaving could have raced a still-unpushed merge).

This is the second time this exact shape occurred this session (the first
being item `3J91Fp7o`'s builder, which stalled similarly and was recovered
the same way without incident because the orchestrator's edits there were
smaller).

## Non-goals

Not proposing that agents and the orchestrator never share a worktree, or
that the orchestrator stop taking over stalled builds directly — that
recovery path is working and fast. Not about the underlying cause of the
agent's own stall (losing track of a backgrounded long-running command),
which is a separate, already-observed pattern with its own mitigation
(never end a turn with a long command still running in the background).
