Add one short paragraph to the emitted brief template(s) — `gitboard
brief builder`, `gitboard brief review`, and `gitboard brief research`
share the "run the gate" and "wait for a background result" instruction
— stating explicitly: when starting a long-running command (a build, a
full gate run) in the background, block on it SYNCHRONOUSLY in the same
turn (e.g. `while kill -0 <PID> 2>/dev/null; do sleep 5; done`, or just
run the command in the foreground without backgrounding it at all) —
never end the turn assuming something will notify you; a subagent has
no persistent monitoring between turns. This is a text change to
whatever module renders `gitboard brief`'s output (find it via `git grep
-rn "run the repo's gate locally" _work/` or equivalent in the board
tooling), verified by re-running `gitboard brief builder <id>` on any
item and confirming the new paragraph appears.
