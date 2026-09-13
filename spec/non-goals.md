- No binding change. `db:readonly()`/`st:readonly()`'s return shapes
  are frozen.
- Do not touch `test/tool/net/**` or `test/tool/BUILD.mk`; retirement is
  `3IOCgtWA`.
- Do not expand this into a broader `lsqlite3` test suite; port exactly
  what `sqlite_test.lua` asserts. A fuller `lsqlite3` coverage gap (if
  one exists beyond `readonly()`) is a separate finding, not this
  slice's scope.
