In `tool/net/lsqlite3.c`'s `db_wal_checkpoint` (~line 936-938), push
the error message alongside the code:
```c
if (sqlite3_wal_checkpoint_v2(db->db, db_name, eMode, &nLog, &nCkpt) != SQLITE_OK) {
    lua_pushnil(L);
    lua_pushstring(L, sqlite3_errmsg(db->db));
    lua_pushinteger(L, sqlite3_errcode(db->db));
    return 3;
}
```
Update `tool/net/definitions.lua:976-977` to:
```
---@return integer|nil nlog, integer nckpt
---@return string? errormsg
---@return lsqlite3.ResultCode? errno
```
