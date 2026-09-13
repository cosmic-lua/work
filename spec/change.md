`tool/net/lsqlite3.c`'s `db_register_extension` (around line 1098):
treat `rc == SQLITE_OK_LOAD_PERMANENTLY` as success alongside
`rc == SQLITE_OK`, not as a failure. `SQLITE_OK_LOAD_PERMANENTLY` is
an existing, already-`#include`d sqlite3.h constant (extended-result-
code family), so no new definition is needed — only the success check
at the call site widens.

Add a regression case to
`tool/lua/test_sqlite_register_extension.lua` covering `appendvfs`
specifically (or whichever loadable unit is the first
`SQLITE_OK_LOAD_PERMANENTLY`-returning one landed), asserting
`db:register_extension("appendvfs")` returns success rather than
`nil, "not an error", 256`.

`tool/net/definitions.lua`'s existing `@return` annotation for
`register_extension` already documents a `boolean, string` shape;
confirm it needs no change (the fix only widens which underlying `rc`
values map to the documented `true`).
