In `tool/net/lsqlite3.c`'s `db_prepare` (~line 1606-1611), push the
error message directly instead of the bare code:
```c
if (sqlite3_prepare_v2(db->db, sql, sql_len, &svm->vm, &sqltail) != SQLITE_OK) {
    lua_pushnil(L);
    lua_pushstring(L, sqlite3_errmsg(db->db));
    lua_pushinteger(L, sqlite3_errcode(db->db));
    if (cleanupvm(L, svm) == 1) lua_pop(L, 1);
    return 3;
}
lua_pushstring(L, sqltail);
return 2;
```
Update `tool/net/definitions.lua:872-874` to reflect the widened,
now-honest shape, e.g.:
```
---@return lsqlite3.Statement|nil stmt
---@return string? tail_or_error SQL past the first statement on success; the error message on failure
---@return lsqlite3.ResultCode? errorcode present on failure only
```
(keep documenting that slot 2 still doubles as tail-on-success — that
asymmetry is inherent to the underlying C API and is fine, as long as
the FAILURE case is a string, matching this repo's own rule that "slot
2 is the error" whenever slot 1 admits nil).
