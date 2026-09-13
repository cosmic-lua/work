- Not the batch-1 extraction-rule question itself (`3InoAi3b`) — this
  is a distinct, pre-existing defect in `lsqlite3.c`'s registration
  path, surfaced by wiring `appendvfs` in, not caused by it.
- Not auditing every other extension's init for the same
  `SQLITE_OK_LOAD_PERMANENTLY` pattern beyond confirming the fix is
  general (checks the `rc` value, not the specific extension name).
