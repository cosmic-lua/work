## Evidence

`gitboard help review`'s own doctrine text says: "A solo session
reviewing without an orchestrator instead self-names (`take ID` under
its own review-<ID>-<unique>)." Read literally this means: construct a
distinct session-label string yourself and pass it explicitly.

Followed literally this session (reviewing `t5hA_ZnKG` solo, no
orchestrator): `take t5hA_ZnKG --session "review-t5hA_ZnKG-self0007"`
succeeded, claiming the review under that label — but the next call,
`worktree t5hA_ZnKG --review`, was refused: "REFUSED: 3IyVRoL5 is
claimed by review-t5hA_ZnKG-self0007, not
6141b568-f7a6-5a55-b674-7af59f6e37ac — take it first". `worktree`
derives the caller's identity from the environment (the real session
id), not from whatever string a prior `take --session` recorded, so
any `--session` value other than the environment's own derived one
makes every later board call in the same solo session look like a
different claimant. Recovered with `take t5hA_ZnKG --force --why
"solo review, no subagent spawn this session"` (with no `--session`,
letting it derive from environment) — one extra call and a `--force`
that should never have been needed.

## Change

`gitboard help review`'s "self-names" sentence: replace the
parenthetical with the actual working form — omit `--session` entirely
so `take` derives the caller's identity from the environment, the same
identity every later `worktree`/`verdict` call in that session will
also derive. State explicitly that passing an explicit `--session`
string here is the orchestrator-only path (naming a label a Task/Agent
subagent will claim under) and is wrong for a session reviewing in its
own right.

## Non-goals

No change to `take`'s actual claiming logic — the tool's behavior is
correct and consistent (identity always comes from the environment
unless a caller is impersonating a distinct named claimant); only the
doc text misleads.

## Access

cosmic-lua/work, read and write on a branch; no other repository.

## Ready when

`gitboard help review`'s self-naming sentence names the literal
working command (`take ID`, no `--session`) rather than a constructed
label string.
