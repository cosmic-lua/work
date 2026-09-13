- Do not fold in the separate tuple-completeness question (the
  `@return string?` annotation dropping the second value that
  `pusherrstr` actually pushes on the `buffer == NULL` path) as a
  blocking requirement — note it, fix it if convenient, but the crash
  fix is the point of this capture.
- No change to `db_deserialize` (`tool/net/lsqlite3.c:1786-1798`,
  guarded by the same `SQLITE_ENABLE_DESERIALIZE`) unless inspection
  during the fix turns up the same allocator mismatch there — if so,
  say so in the PR rather than silently expanding scope.
