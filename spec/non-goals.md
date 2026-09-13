- **No toolchain change.** No discovery walk, no compile/check seam, no
  generated tail, no `_cli/lint.tl` edit, no `_tool/testrun.tl` edit, no
  `.tests` format change, no `--filter` flag. Those belong to 3IOCdHTM
  and 3IOCdZCA. `_tool/records.tl` itself is not touched — only its test
  file gains one function.
- **No test file in the tree migrates.** The 2,870 self-call lines stay
  (3IOCdooE). The tree remains entirely legacy mode, which is why this
  slice lands green with zero edits to existing tests.
- **`main` never exits and never throws.** D23 permits only
  `cosmic.check` (and D22's CSPRNG) to exit or throw from `cosmic.*`, and
  D29's own consequences say D23 stands unchanged. Turning this return
  value into the process's exit status is 3IOCdHTM's job and its tail
  must therefore be
  `os.exit(require("cosmic.test").main({...}))` — D29's illustrative
  `return require("cosmic.test").main({...})` exits 0 on failure, because
  `cmd/cosmic/main.tl:476` discards the chunk's return value. Do not
  "fix" that here by exiting from the module, and do not edit
  `cmd/cosmic/main.tl`.
- **No per-test skip, no subtests, no `t` handle, no per-test temp
  directory, no per-test wall time, no parallelism, no shuffle.** Each is
  rejected or deferred by D29.
- **No assertion vocabulary grows.** `assert` and `cosmic.check` remain
  the whole of it.
- **No docs prose.** `AGENTS.md`, `docs/guides/**` and `sys/help.md`
  describe the convention as it IS, and it does not change until the
  toolchain lands. The module's `---` header is the only documentation
  this slice writes, and no decision record is amended.
- **Frozen:** the 0/2/fail exit grammar; the `records` row and counts
  spellings (reproduce them exactly, never redefine them); and, once this
  ships, `main`'s signature, by D20's charter as D29 notes.
