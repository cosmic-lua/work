1. `third_party/lua/cosmo/lunix.c`, `LuaUnixSigprocmask`: validate
   `how` inline against the three named constants and raise on
   anything else:

   ```c
   // unix.sigprocmask(how:int, newmask:unix.Sigset)
   //     └─→ oldmask:unix.Sigset
   static int LuaUnixSigprocmask(lua_State *L) {
     sigset_t oldmask;
     int olderr = errno;
     int how = luaL_checkinteger(L, 1);
     if (how != SIG_BLOCK && how != SIG_UNBLOCK && how != SIG_SETMASK) {
       errno = olderr;
       return luaL_argerror(L, 1, lua_pushfstring(L, "invalid how %d", how));
     }
     sigprocmask(how, luaL_checkudata(L, 2, "unix.Sigset"), &oldmask);
     LuaPushSigset(L, oldmask);
     return 1;
   }
   ```

   (EFAULT is already unreachable per the Evidence above, so once
   `how` is validated the syscall cannot fail; the return-code check
   is dropped, matching `LuaUnixGettime`'s post-#277 shape.)

2. `tool/net/definitions.lua`, same commit — the return block becomes
   exactly `---@return unix.Sigset oldmask`, the error/errno lines
   deleted (the `how` prose above stays unchanged; it already
   enumerates the only three valid values):

   ```
   ---@param newmask unix.Sigset
   ---@return unix.Sigset oldmask
   function unix.sigprocmask(how, newmask) end
   ```

3. `tool/lua/test_signal.lua`: add beside the existing
   `unix.sigset`/`unix.sigprocmask` coverage, before the trailing
   `print("PASS")`:

   ```lua
   -- sigprocmask's only reachable failure is an invalid `how`;
   -- EFAULT needs a pointer this binding never constructs from Lua.
   assert(not pcall(unix.sigprocmask, 999, unix.sigset()),
     "sigprocmask of an invalid how must raise")
   ```
