- **No compile seam, no generated tail, no runner consumer.** Nothing
  calls `scan` in this slice but the lint. `_tool/testrun.tl`,
  `_make/testrun.tl`, `cmd/cosmic/main.tl` and the `.tests` format are
  untouched; that is 3IOCdHTM's and 3IOCdZCA's.
- **No test file in the tree migrates.** All 267 stay legacy;
  3IOCdooE owns the migration. A diff that edits a `*_test.tl` other
  than `_cli/lint_test.tl` is out of scope.
- **`cosmic/test.tl` is not touched**, and `Discovery.Case` is
  deliberately NOT `cosmic.test`'s `Case`: one names a source
  position, the other carries a function, and `_tool/**` may not be
  required from a `cosmic/**` module anyway.
- **The rule keeps its name, its exported signature and its
  `_test%.tl$` scoping.** `check_call_after_define` stays on
  `_cli.lint`'s record with the same three parameters, or the four
  existing tests stop being a regression net.
- **`end_line_of` moves; it does not change.** Its block-depth
  handling — the `pending_do` flag and its comment — is load-bearing
  and stays byte-identical.
- **No new lint rule and no `--check lint` CLI change.**
- **Frozen:** the `Diagnostic` record's fields; the `call-after-define`
  rule name, which `docs/guides/lint.md` documents; D29.
