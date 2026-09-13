Drop `COSMIC_MAKE_ROOT` from the environment the test runner hands each test
process, in `_tool/testrun.tl`.

The runner already builds the child environment by copying `env.all()` with
one key handled specially: `COSMIC_COVERAGE` is intercepted rather than
inherited, so each test gets its own coverage directory instead of the outer
one. Add `COSMIC_MAKE_ROOT` to that same loop as a key the child never
inherits — the root a test resolves must come from its own cwd (or from a
value the test sets for itself), never from whatever the outer `--make`
invocation was told.

Concretely, in the `for key, val in pairs(env.all())` loop that fills
`child_env`, treat `COSMIC_MAKE_ROOT` like `COSMIC_COVERAGE`'s existing
branch: skip it, so it is never appended to `child_env`. Extend the loop's
comment to say why — an inherited root would override the cwd every fixture
project depends on.

Add a test to `_tool/testrun_test.tl` named
`test_make_root_is_not_inherited`: set `COSMIC_MAKE_ROOT` in the calling
process, run a trivial script through `testrun.run` that prints whether
`os.getenv("COSMIC_MAKE_ROOT")` is set, assert the child saw nothing, and
restore the outer value.

**Why the runner and not the two tests.** The finding that produced this item
named `_make/check_test.tl` and `_cli/main_handlers_test.tl` as the files to
scrub. They are the two that were observed failing, but they are not the
boundary: five spawn sites across them inherit the full parent environment
(`_make/check_test.tl:63`, `:310`, `:409`, `_cli/main_handlers_test.tl:34`,
`:158`), and any future fixture spawn would inherit it too. Fixing it at the
runner closes all five and every later one in one place. It is also the only
fix that fits: `_make/check_test.tl` is 488 lines against the hard 500-line
cap, so the seven-line hermetic env list its sibling `_make` tests each define
in-file cannot be added at three sites there.

**Why this is safe.** No test reads an inherited `COSMIC_MAKE_ROOT`. Every
test that wants one sets it for itself — either in-process via
`cosmic.env.set`/`unset` around the call, or explicitly in a child's `env`
table (`_make/check_test.tl:326`, which is `test_root_override` and stays
green because it passes the value rather than inheriting it).
`_make/root_test.tl:71-79` saves and unsets the variable and restores it only
if it was set, so it is correct under either state.

```facts
$ grep -c COSMIC_COVERAGE _tool/testrun.tl
2
$ grep -c COSMIC_MAKE_ROOT _tool/testrun.tl
0
$ wc -l < _tool/testrun.tl
328
$ wc -l < _make/check_test.tl
488
$ wc -l < _cli/main_handlers_test.tl
255
$ grep -c child.start _make/check_test.tl
4
$ grep -n "child.start" _cli/main_handlers_test.tl
34:  local h = check.must(child.start(argv))
158:  local h = check.must(child.start({cosmic, "--make", "check", "a.tl"},
```
