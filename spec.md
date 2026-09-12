## Evidence

`_work/fixture.tl`'s single git-command helper `git(cwd, argv)`
(`_work/fixture.tl:47-56`, `assert(r.ok, "git " .. table.concat(argv, " ")
.. " failed: " .. r.stderr)` at line 56) is what `_work/worktree_runtime_test.tl`'s
`fresh()` helper calls to run `git worktree add -q --detach <root> HEAD`
(`_work/worktree_runtime_test.tl:44`) once per `fresh(...)` invocation, and
`test_pin_grammar_and_committed_working_agreement` calls `fresh("pin", ...)`
up to 26 times plus `fresh("pin-mismatch", ...)` once, all in the same
test-file process.

This exact call has failed on GitHub Actions with the identical signature
twice in two consecutive PRs from this session, both times in a file the
PR's diff never touched, both times passing cleanly on a single re-run:

1. cosmic-lua/work PR #124, merge-queue run `34669788264` job
   `103488856118` (branch `gh-readonly-queue/main/pr-124-...`, head_sha
   `bb1fccf85c5fd69b1cc276da7939e717ac68bfc8`, 2026-09-12T03:15:14Z):
   ```
   .coverage/_work/worktree_runtime_test.tl (exit 1):
     failing tests:
       test_pin_grammar_and_committed_working_agreement
     stdout:
       ✗ test_pin_grammar_and_committed_working_agreement
           /home/runner/work/work/work/o/_work/fixture.lua:56: git worktree add -q --detach /home/runner/work/work/work/o/.coverage/_work/worktree_runtime_test.tl.test.tmp.d/testrun_tv5t6t/runtime-pin-xwcq0d/target HEAD failed: fatal: could not open '.git/worktrees/target/locked' for writing: No such file or directory
   ```
2. cosmic-lua/work PR #125, run `34671020702` job `103492269033`
   (head_sha `55ec46c4526ad1b164873a283497326510e6d832`, 2026-09-12T03:42:30Z):
   ```
   .coverage/_work/worktree_runtime_test.tl (exit 1):
     failing tests:
       test_pin_grammar_and_committed_working_agreement
     stdout:
       ✗ test_pin_grammar_and_committed_working_agreement
           /home/runner/work/work/work/o/_work/fixture.lua:56: git worktree add -q --detach /home/runner/work/work/work/o/.coverage/_work/worktree_runtime_test.tl.test.tmp.d/testrun_4gx9dq/runtime-pin-mismatch-ba0qt7/target HEAD failed: fatal: could not open '.git/worktrees/target/locked' for writing: No such file or directory
   ```

Both failures share the identical error text at the identical source
line, from the identical `git worktree add` invocation shape, against a
freshly created single-commit repo — an ENOENT writing git's own internal
`<gitdir>/worktrees/<name>/locked` marker file. This reads as a transient
race inside git's own worktree-add bookkeeping on the runner's
filesystem, not a defect in the test's logic: the same commands run
deterministically in every local run this session, and the two CI
occurrences are on otherwise-unrelated PRs whose diffs never touch this
file. Each occurrence cost one full CI cycle (2-3 minutes) plus an
orchestrator investigation-and-rerun step, and stood between a green
head and merge on both PRs.

## Change

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

## Non-goals

Not adding retries to any other git invocation in `_work/fixture.tl` or
elsewhere in `_work/`. Not touching gitboard's own production `worktree`
command path (`_work/gitworktree.tl`) — this is scoped to the TEST
fixture helper only. Not attempting to root-cause the underlying
git/filesystem race itself (a GitHub Actions runner or git-internals
issue outside this repo's control) — only to stop it from failing CI
when it fires. Not weakening, thinning, or removing
`test_pin_grammar_and_committed_working_agreement` or any other test to
work around this.

## Access

cosmic-lua/work, read and write on a branch; no other repository.
