Add a narrow, bounded retry in `_work/fixture.tl`'s `git()` helper
(`_work/fixture.tl:47-56`) specifically for a `git worktree add`
invocation that fails with this exact transient signature — the command
failing with a `.git/worktrees/<name>/locked` ENOENT-on-write message —
retrying the same `git worktree add` call (same argv, no changes) once
or twice before giving up and failing loudly exactly as today. Do not
broaden the retry beyond this: a `git worktree add` failure with any
other message, or a failure from any other git subcommand, must still
fail on the first attempt exactly as it does today. Land a regression
test that injects this exact failure text through a stubbed/faked
command runner and asserts the retry recovers, without spawning real
git processes to try to reproduce the flake itself.
