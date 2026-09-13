1. `third_party/lua/cosmo/lunix.c`, `LuaUnixSetitimer`: replace the
   4-value push (lines 2784-2787) with one table:

   ```c
   // unix.setitimer(which[, intervalsec, intns, valuesec, valuens])
   //     ├─→ previous:table
   //     └─→ nil, error:str, errno:int
   static int LuaUnixSetitimer(lua_State *L) {
     int which, olderr = errno;
     struct itimerval it, oldit, *itptr;
     which = luaL_checkinteger(L, 1);
     if (!lua_isnoneornil(L, 2)) {
       itptr = &it;
       it.it_interval.tv_sec = luaL_optinteger(L, 2, 0);
       it.it_interval.tv_usec = luaL_optinteger(L, 3, 0) / 1000;
       it.it_value.tv_sec = luaL_optinteger(L, 4, 0);
       it.it_value.tv_usec = luaL_optinteger(L, 5, 0) / 1000;
     } else {
       itptr = 0;
     }
     if (!setitimer(which, itptr, &oldit)) {
       lua_newtable(L);
       lua_pushinteger(L, oldit.it_interval.tv_sec);
       lua_setfield(L, -2, "intervalsec");
       lua_pushinteger(L, oldit.it_interval.tv_usec * 1000);
       lua_setfield(L, -2, "intervalns");
       lua_pushinteger(L, oldit.it_value.tv_sec);
       lua_setfield(L, -2, "valuesec");
       lua_pushinteger(L, oldit.it_value.tv_usec * 1000);
       lua_setfield(L, -2, "valuens");
       return 1;
     } else {
       return LuaUnixSysretErrno(L, "setitimer", olderr);
     }
   }
   ```

2. `tool/net/definitions.lua`, same commit:

   ```
   --- Previous interval-timer setting returned by `setitimer`.
   ---@class unix.Itimerval
   ---@field intervalsec integer
   ---@field intervalns integer
   ---@field valuesec integer
   ---@field valuens integer

   ---@param which integer
   ---@param intervalsec integer
   ---@param intervalns integer needs to be on the interval `[0,1000000000)`
   ---@param valuesec integer
   ---@param valuens integer needs to be on the interval `[0,1000000000)`
   ---@return unix.Itimerval|nil previous
   ---@return string? error
   ---@return unix.Errno? errno
   ---@overload fun(which: integer): unix.Itimerval
   function unix.setitimer(which, intervalsec, intervalns, valuesec, valuens) end
   ```

   (A flat 4-field table was chosen over nesting `interval`/`value`
   sub-tables — matching `unix.SleepRemainder`'s flat precedent and
   this binding's own already-flat argument list, so the migration on
   the cosmic side is a mechanical `.field` rewrite with no new nesting
   to reason about.)

3. `tool/lua/test_signal.lua`: add, before the trailing `print("PASS")`:

   ```lua
   -- setitimer now bundles its previous-value success fields into one
   -- table (tool/net/definitions.lua); pin both branches.
   local prev = assert(unix.setitimer(unix.ITIMER_REAL, 0, 0, 0, 0))
   assert(type(prev) == "table" and type(prev.intervalsec) == "number",
     "a successful setitimer must return one table")
   local bad, err, eno = unix.setitimer(999)
   assert(bad == nil, "setitimer(999) must report nil")
   assert(type(err) == "string", "the error must be a string, not a table field")
   assert(eno == unix.EINVAL, "errno must be EINVAL, not a table field")
   ```
