- **No new module and no wrapper.** `cosmic.sqlite` reaches `zipfile`
  as it stands; do not add `cosmic.artifact`, `cosmic.zip`, or a
  helper to `cosmic/sqlite/**`. No file under `cosmic/sqlite/` is
  edited — only the new example file is added beside them.
- **Do not write the test suite.** Freezing the zipfile contract with
  a `cosmic/sqlite/` test file is board item `3IMcreeF`, deliberately
  separate: this slice documents, that one gates. An example is not a
  substitute and this slice does not become one.
- **Do not touch whilp/cosmopolitan.** The registration is one line in
  the fork (`tool/net/lsqlite3.c` calling `sqlite3_zipfile_init`).
  Frozen C boundary; nothing here changes it.
- **Do not touch `sys/help.md`.** Its guide list is a curated five out
  of twelve, not an index; adding a sixth is a separate judgment.
- **Do not edit any existing guide** beyond the single index.md
  bullet.
- **Nothing writes into the committed tree.** Every mutating statement
  in the example and in the guide's prose operates on a copy under
  `fs.temp_dir()`. An example that edited `o/bin/cosmic` in place
  would corrupt the toolchain mid-gate.
- **Do not claim `zipfile` reclaims space or edits in place.** It
  appends; the measured DELETE grew the file. Say so.
