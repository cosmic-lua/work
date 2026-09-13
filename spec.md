## Change

`gitboard brief review ID` with no `--gitboard-command` emits the literal
token `GITBOARD-INVOCATION-UNRESOLVED-ASK-THE-CALLER` as the prefix of
every board command the brief prints, while the same brief instructs the
reviewer never to guess an invocation. The two together are a dead end
the reviewer has to dig out of. Measured 2026-09-13 on «trIG_klI2»:

```
$ gitboard brief review trIG_klI2 --out /tmp/rev.txt
gitboard-brief: review brief for «trIG_klI2» written … — fill <WORKTREE> …
$ grep -c 'GITBOARD-INVOCATION-UNRESOLVED-ASK-THE-CALLER' /tmp/rev.txt
3
```

The reviewer spawned from that brief reported the cost: about six tool
calls and one WRONG verdict attempt — it reasoned its way to
`/home/user/cosmic/bin/gitboard --dir /home/user/cosmic/o/board`, a
stale unrelated clone, and was refused with `verdict belongs to its claim
holder` — before reading `bin/gitboard` and learning the wrapper resolves
the live board itself. `brief`'s help documents the flag
(`--gitboard-command TEXT … requires --gitboard-cwd`) and says a builder
brief with `--receipt` recovers the invocation from the receipt; a review
brief has no receipt and no fallback, so the omission is a caller
mistake the tool currently launders into the agent's problem.

Make the omission the CALLER's refusal, the way a missing claim already
is: `brief review` (and any other kind with no receipt to fall back on)
refuses when `--gitboard-command` is absent, naming the two flags, and
never writes a brief carrying the placeholder. The refusal is cheap and
lands where the mistake was made; the placeholder is expensive and
lands three hops away in a context that has been told not to fix it.

`_work/brief_gitboard_cmd_test.tl` (4 cases) is where the invocation
prefix is tested; add the refusal case there, and a case that a builder
brief with a receipt still succeeds without the flag.

## Non-goals

Inferring the invocation from the environment. The brief's own reasoning
for the flag — the caller's exact loader plus absolute executable is what
a subagent should run, and only the caller knows it — stands. A refusal
that names the flag is the fix; a guess is the thing the flag exists to
prevent.

Changing what a builder brief with `--receipt` does. That path already
resolves correctly.
