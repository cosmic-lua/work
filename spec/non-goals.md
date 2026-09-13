- **`_make/lockdir.tl` is not touched.** The build-writer lock is not
  broken; only the tests' undeclared non-root assumption is.
- **Do not put `--- requires:` on `_make/lockdir_test.tl`.** It would
  skip six mode-independent cases under root, trading a false FAIL for
  silent loss of the coverage that matters most in that environment.
- **Do not gate on the uid.** `os.getenv("USER")`, a `geteuid` binding,
  or "am I root" in any form is rejected: it is wrong for
  `CAP_DAC_OVERRIDE` without root and for a filesystem mounted without
  mode enforcement, both of which the behavioural probe catches.
- **Do not register it as `required_linux_ci = false`.** Making absence
  non-fatal everywhere would let the supported lane start running as
  root and silently stop exercising these two cases — the exact failure
  mode this item is about, moved one level up.
- **No per-case skip mechanism.** The runner's contract is whole-file
  (`_tool/testplan.tl`), and adding a per-function variant is a change to
  the test runner, not to this test. The split is how a file with mixed
  requirements is expressed today.
