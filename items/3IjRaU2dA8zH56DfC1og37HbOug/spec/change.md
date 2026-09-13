1. `third_party/lua/cosmo/lunix.c`, the SHARED `LuaUnixTime` helper:
   replace the 11-value positional push with one table, changing
   `gmtime` and `localtime` together:

   ```c
   static dontinline int LuaUnixTime(lua_State *L, const char *call,
                                     struct tm *f(const time_t *, struct tm *)) {
     int64_t ts;
     struct tm tm;
     int olderr = errno;
     ts = luaL_checkinteger(L, 1);
     if (f(&ts, &tm)) {
       lua_newtable(L);
       lua_pushinteger(L, tm.tm_year + 1900); lua_setfield(L, -2, "year");
       lua_pushinteger(L, tm.tm_mon + 1);     lua_setfield(L, -2, "mon");
       lua_pushinteger(L, tm.tm_mday);        lua_setfield(L, -2, "mday");
       lua_pushinteger(L, tm.tm_hour);        lua_setfield(L, -2, "hour");
       lua_pushinteger(L, tm.tm_min);         lua_setfield(L, -2, "min");
       lua_pushinteger(L, tm.tm_sec);         lua_setfield(L, -2, "sec");
       lua_pushinteger(L, tm.tm_gmtoff);      lua_setfield(L, -2, "gmtoffsec");
       lua_pushinteger(L, tm.tm_wday);        lua_setfield(L, -2, "wday");
       lua_pushinteger(L, tm.tm_yday);        lua_setfield(L, -2, "yday");
       lua_pushinteger(L, tm.tm_isdst);       lua_setfield(L, -2, "dst");
       lua_pushstring(L, tm.tm_zone);         lua_setfield(L, -2, "zone");
       return 1;
     } else {
       return LuaUnixSysretErrno(L, call, olderr);
     }
   }
   ```

   `LuaUnixGmtime`/`LuaUnixLocaltime` themselves (lines 2855-2864) are
   unchanged — both already just forward to this helper.

2. `tool/net/definitions.lua`, same commit — ONE new shared class, and
   BOTH `gmtime`'s and `localtime`'s return blocks rewritten to it:

   ```
   --- Broken-down time returned by `gmtime`/`localtime`.
   ---@class unix.BrokenDownTime
   ---@field year integer
   ---@field mon integer 1 ≤ mon ≤ 12
   ---@field mday integer 1 ≤ mday ≤ 31
   ---@field hour integer 0 ≤ hour ≤ 23
   ---@field min integer 0 ≤ min ≤ 59
   ---@field sec integer 0 ≤ sec ≤ 60
   ---@field gmtoffsec integer ±93600 seconds
   ---@field wday integer 0 ≤ wday ≤ 6
   ---@field yday integer 0 ≤ yday ≤ 365
   ---@field dst integer 1 if daylight savings, 0 if not, -1 if unknown
   ---@field zone string
   ```

   `unix.gmtime`'s block becomes:
   ```
   ---@param unixts integer
   ---@return unix.BrokenDownTime|nil
   ---@return string? error
   ---@return unix.Errno? errno
   ---@nodiscard
   function unix.gmtime(unixts) end
   ```

   `unix.localtime`'s block becomes the same shape, minus
   `---@nodiscard` (the original didn't have it either) — keep all of
   `localtime`'s existing prose (the timezone-database list, the `TZ`
   note) unchanged, only its `---@param`/`---@return` lines move.

3. `tool/lua/test_unix_misc.lua`: rewrite the existing `gmtime`
   success block (currently lines 36-44) to the new table shape, and
   add a failure-shape assertion:

   ```lua
   -- gmtime: success returns one table (tool/net/definitions.lua).
   local bdt = assert(unix.gmtime(1657297063))
   assert(bdt.year == 2022 and bdt.mon == 7 and bdt.mday == 8
     and bdt.hour == 16 and bdt.min == 17 and bdt.sec == 43
     and bdt.gmtoffsec == 0 and bdt.wday == 5 and bdt.yday == 188
     and bdt.dst == 0 and bdt.zone == "UTC")

   -- gmtime's one reachable failure (EOVERFLOW) is a clean nil, string,
   -- errno tuple now — nothing shares a slot with a BrokenDownTime field.
   local goy, gerr, geno = unix.gmtime(9223372036854775807)
   assert(goy == nil, "gmtime of an unrepresentable timestamp must report nil")
   assert(type(gerr) == "string", "the error must be a string")
   assert(geno == unix.EOVERFLOW, "errno must be EOVERFLOW")
   ```
