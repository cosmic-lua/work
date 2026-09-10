## Evidence

`_make/lockdir_test.tl`'s `test_terminal_errno_and_turnover_classification`
and `test_cleanup_error_is_not_contention` fail on current `main`
(`a44b020d`) when run as root, in both a pristine `/home/user/cosmic`
checkout and an independent rebased worktree:

```
o/_make/lockdir_test.lua:193: terminal EACCES is not ENOTEMPTY
o/_make/lockdir_test.lua:345: cleanup EACCES is not busy
```

Both assertions expect a specific errno from a permission-restricted
directory operation (`ENOTEMPTY`/a "busy" condition); running as root
gets `EACCES` instead — consistent with root bypassing whatever
permission setup the test relies on to produce the expected errno.
This container runs the whole session as root (`whoami` → `root`), and
nothing in the test's header declares a `--- requires:` capability, so
the runner does not report it as `UNAVAILABLE` — it reports a hard
product `FAIL` indistinguishable from a real regression.

Cost: on 2026-09-10, this cost one full investigation (confirming it
reproduces identically on a completely unmodified `main` checkout)
before a completed, verified board item's own `--make ci` run could be
trusted as green. It will cost the same investigation again for every
future item whose full-gate run happens to include this file, in any
root-run environment (this session's own remote container included).

## Non-goals

Not a claim that the feature (`_make`'s build-writer lock) is broken —
only that the test's non-root assumption isn't declared, so a root
environment can't distinguish this from a real failure without manual
investigation each time.
