1. **`third_party/lua/lunix.c`**, `LuaUnixGettime`: hoist the clock id
   and raise the standard bad-argument error on failure:

   ```c
   static int LuaUnixGettime(lua_State *L) {
     struct timespec ts;
     int olderr = errno;
     int clock = luaL_optinteger(L, 1, CLOCK_REALTIME);
     if (!clock_gettime(clock, &ts)) {
       lua_pushinteger(L, ts.tv_sec);
       lua_pushinteger(L, ts.tv_nsec);
       return 2;
     }
     errno = olderr;
     return luaL_argerror(
         L, 1, lua_pushfstring(L, "invalid or unsupported clock id %d", clock));
   }
   ```

   (Restore `errno` before raising, as `LuaUnixSysretErrno` did.)

2. **`tool/net/definitions.lua`**, same commit: the return block
   (lines 5849–5851) becomes exactly
   `---@return integer seconds, integer nanos` — the error and errno
   return lines are deleted. Replace the prose lines 5843–5845
   ("Returns `EINVAL` if clock isn't supported on platform." / "This
   function only fails if `clock` is invalid.") with: "An invalid
   clock id, or one this platform cannot serve (the `_COARSE` clocks
   on extremely old Linux distros), raises a bad-argument error — wrap
   the call in `pcall` to feature-probe a nonstandard clock. The
   per-clock guarantees above name the clocks that can never fail."
   `---@nodiscard` stays.

3. **`tool/lua/test_definitions_conformance.lua`**: add
   `probe("unix.clock_gettime", unix.clock_gettime)` beside
   `probe("unix.getpid", ...)` (line 253) — the binding is
   side-effect-free, so it belongs in the probed set and now verifies
   two plain integer slots — and in the `=== failure shapes ===`
   section (line 372):

   ```lua
   assert(not pcall(unix.clock_gettime, -1),
     "clock_gettime of an invalid clock id must raise")
   ```

   No slot-observation entry is needed: the binding no longer declares
   an error slot.
