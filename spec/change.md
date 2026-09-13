`gitboard help review`'s "self-names" sentence: replace the
parenthetical with the actual working form — omit `--session` entirely
so `take` derives the caller's identity from the environment, the same
identity every later `worktree`/`verdict` call in that session will
also derive. State explicitly that passing an explicit `--session`
string here is the orchestrator-only path (naming a label a Task/Agent
subagent will claim under) and is wrong for a session reviewing in its
own right.
