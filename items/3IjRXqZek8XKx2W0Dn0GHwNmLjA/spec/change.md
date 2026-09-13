1. `third_party/lua/cosmo/lunix.c`, `LuaUnixRaise`: validate `sig`
   inline and raise a standard bad-argument error on failure,
   mirroring `LuaUnixGettime`'s post-#277 shape and
   `LuaUnixSigaction`'s existing `1 <= sig && sig <= NSIG` check
   (widened here to admit 0, raise's own valid existence-check value):

   ```c
   // unix.raise(sig:int)
   //     └─→ rc:int
   static int LuaUnixRaise(lua_State *L) {
     int olderr = errno;
     int sig = luaL_checkinteger(L, 1);
     if (!(0 <= sig && sig <= NSIG)) {
       errno = olderr;
       return luaL_argerror(
           L, 1, lua_pushfstring(L, "invalid signal number %d", sig));
     }
     lua_pushinteger(L, raise(sig));
     return 1;
   }
   ```

2. `tool/net/definitions.lua`, same commit — the return block (lines
   5033-5035) becomes exactly `---@return integer rc` and the
   error/errno lines are deleted; add one prose sentence:

   ```
   --- Triggers signal in current process.
   ---
   --- This is pretty much the same as `kill(getpid(), sig)`. Raises a
   --- bad-argument error if `sig` is not `0` (existence check only,
   --- like `kill(pid, 0)`) or a valid signal number — POSIX's only
   --- documented failure for `raise()`, `EINVAL`.
   ---@param sig integer
   ---@return integer rc
   function unix.raise(sig) end
   ```

3. `tool/lua/test_signal.lua`: add, beside the existing
   sigaction/sigprocmask coverage, before the trailing `print("PASS")`:

   ```lua
   -- raise()'s only documented failure is an invalid signal number
   -- (EINVAL); sig == 0 is a legitimate existence-check call (like
   -- kill(pid, 0)) and must not raise.
   assert(not pcall(unix.raise, 999),
     "raise of an invalid signal number must raise")
   assert(unix.raise(0) == 0, "raise(0) is a valid existence check")
   ```
