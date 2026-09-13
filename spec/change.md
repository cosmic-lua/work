1. `third_party/lua/cosmo/lunix.c`, `LuaUnixClearenv`: drop the
   return-code check entirely — `clearenv()` has no failure path to
   check for:

   ```c
   // unix.clearenv()
   //     └─→ true
   static int LuaUnixClearenv(lua_State *L) {
     clearenv();
     lua_pushboolean(L, 1);
     return 1;
   }
   ```

2. `tool/net/definitions.lua`, same commit:

   ```
   --- Clears all environment variables.
   ---
   --- This wraps the C `clearenv()` function to allow Lua scripts to
   --- remove all environment variables at once. Never fails: this
   --- project's `clearenv()` (`libc/intrin/clearenv.c`)
   --- unconditionally sets `environ = 0` and returns success.
   ---@return true
   function unix.clearenv() end
   ```

3. `tool/lua/test_unix_misc.lua`: add, near the existing
   `unsetenv`/`setenv` coverage:

   ```lua
   -- clearenv has no reachable failure: this project's clearenv()
   -- (libc/intrin/clearenv.c) unconditionally succeeds.
   assert(unix.clearenv() == true, "clearenv must always return true")
   ```
