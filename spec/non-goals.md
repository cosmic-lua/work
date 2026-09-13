Not adding retries to any other git invocation in `_work/fixture.tl` or
elsewhere in `_work/`. Not touching gitboard's own production `worktree`
command path (`_work/gitworktree.tl`) — this is scoped to the TEST
fixture helper only. Not attempting to root-cause the underlying
git/filesystem race itself (a GitHub Actions runner or git-internals
issue outside this repo's control) — only to stop it from failing CI
when it fires. Not weakening, thinning, or removing
`test_pin_grammar_and_committed_working_agreement` or any other test to
work around this.
