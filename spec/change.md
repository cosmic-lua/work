In `tool/net/lsqlite3.c`, change `pusherr` (or add a config-specific
variant) to push `sqlite3_errstr(rc)` in slot 2 instead of the bare
integer, keeping the integer code as an optional slot 3 `errno`:
```c
lua_pushnil(L);
lua_pushstring(L, sqlite3_errstr(rc));
lua_pushinteger(L, rc);
return 3;
```
Update `tool/net/definitions.lua:590-594` to:
```
---@return integer|nil rc, function? prev_func, any prev_udata
---@return string? errormsg
---@return integer? errorcode
```
Separately, consider (implementer's judgment, not required by this
capture) raising via `luaL_argerror` for an `option` outside the four
documented values, matching the `path.join`-class precedent — but
that is a design choice for the fix's author, not gated by this
capture's acceptance bar.
