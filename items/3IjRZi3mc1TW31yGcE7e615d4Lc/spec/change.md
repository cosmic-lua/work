1. `third_party/lua/cosmo/lunix.c`, `LuaUnixSigaction`: replace the
   3-value push (lines 2716-2739) with one table carrying `handler`,
   `flags`, `mask` fields:

   ```c
   // unix.sigaction(sig:int[, handler:func|int[, flags:int[, mask:unix.Sigset]]])
   //     ├─→ previous:table
   //     └─→ nil, error:str, errno:int
   ...
   if (!sigaction(sig, saptr, &oldsa)) {
     lua_rawgetp(L, LUA_REGISTRYINDEX, &kSignalHandlers);
     lua_newtable(L);           // the result table, pushed before the handler lookup consumes the stack
     if (lua_rawgeti(L, -2, sig) != LUA_TFUNCTION) {
       lua_pop(L, 1);
       lua_pushinteger(L, (intptr_t)oldsa.sa_handler);
     }
     lua_setfield(L, -2, "handler");
     if (saptr) {
       if (sa.sa_sigaction == LuaUnixOnSignal) {
         lua_pushvalue(L, -3);
       } else {
         lua_pushnil(L);
       }
       lua_rawseti(L, -3, sig);   // update the registry lua table (unchanged)
     }
     lua_remove(L, -2);           // remove the signal handler table from stack (unchanged)
     lua_pushinteger(L, oldsa.sa_flags);
     lua_setfield(L, -2, "flags");
     LuaPushSigset(L, oldsa.sa_mask);
     lua_setfield(L, -2, "mask");
     return 1;
   } else {
     return LuaUnixSysretErrno(L, "sigaction", olderr);
   }
   ```

   (The exact stack-index arithmetic above is a sketch, not a literal
   patch — `LuaUnixSigaction`'s existing stack juggling around the
   registry handler-table lookup is intricate; the implementer must
   re-derive the precise `lua_newtable`/`lua_setfield`/`lua_remove`
   ordering against the CURRENT function body at
   `third_party/lua/cosmo/lunix.c:2662-2743`, preserving every existing
   comment about why the registry update and the trailing-nil handling
   work the way they do. The invariant to preserve: build ONE table
   with `handler`/`flags`/`mask` fields, return it as the sole success
   value.)

2. `tool/net/definitions.lua`, same commit — new class plus rewritten
   return block:

   ```
   --- Previous signal disposition returned by `sigaction`.
   ---@class unix.SignalAction
   ---@field handler function|integer Previous handler: a Lua function,
   --- `SIG_IGN`, `SIG_DFL`, or a raw function pointer.
   ---@field flags integer Previous `sa_flags`.
   ---@field mask unix.Sigset Previous signal mask.

   ---@param mask? unix.Sigset
   ---@return unix.SignalAction|nil previous
   ---@return string? error
   ---@return unix.Errno? errno
   function unix.sigaction(sig, handler, flags, mask) end
   ```

   Update the doc examples in the same comment block
   (`tool/net/definitions.lua:6639-6653`) that destructure
   `unix.sigaction`'s result — none currently capture `flags`/`mask`
   from a successful call, so no example needs a field-access rewrite,
   but re-check at implementation time.

3. `tool/lua/test_signal.lua`: add, before the trailing `print("PASS")`:

   ```lua
   -- sigaction now bundles its previous-disposition success values
   -- into one table (tool/net/definitions.lua); pin both branches.
   local ok_action = assert(unix.sigaction(unix.SIGUSR1))
   assert(type(ok_action) == "table" and type(ok_action.flags) == "number"
     and ok_action.mask ~= nil,
     "a successful sigaction query must return one table")
   local bad_action, err, eno = unix.sigaction(unix.SIGKILL, unix.SIG_IGN)
   assert(bad_action == nil, "sigaction on SIGKILL must report nil")
   assert(type(err) == "string", "the error must be a string, not a table field")
   assert(eno == unix.EINVAL, "errno must be EINVAL, not a table field")
   ```
