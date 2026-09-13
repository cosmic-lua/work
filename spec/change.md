In `tool/net/lsqlite3.c`, in `lsqlite_do_open` (~line 2417-2420), swap
the push order so the string error message is slot 2 and the numeric
SQLite result code is slot 3:
```c
lua_pushnil(L);
lua_pushstring(L, sqlite3_errmsg(db->db));     /* slot 2: string */
lua_pushinteger(L, sqlite3_errcode(db->db));   /* slot 3: number */
```
Update `tool/net/definitions.lua:552-567` (both `open` and
`open_memory`) to match:
```
---@return lsqlite3.Database|nil db
---@return string? errormsg
---@return lsqlite3.ResultCode? errorcode
```
This is a binding contract change per this repo's own AGENTS.md rule
("a contract change to conform is made deliberately... conformance
probe same PR") — land the `definitions.lua` update in the same
commit as the C change.
