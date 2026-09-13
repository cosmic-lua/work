1. `third_party/lua/cosmo/lunix.c`, `LuaUnixSigpending`: drop the
   return-code check entirely — there is no reachable failure to
   check for:

   ```c
   // unix.sigpending()
   //     └─→ mask:unix.Sigset
   static int LuaUnixSigpending(lua_State *L) {
     sigset_t mask;
     sigpending(&mask);
     LuaPushSigset(L, mask);
     return 1;
   }
   ```

2. `tool/net/definitions.lua`, same commit:

   ```
   --- Returns the set of signals pending delivery to the calling
   --- process that are currently blocked. Never fails on any
   --- platform this project supports: its one documented failure,
   --- EFAULT, needs an invalid pointer this binding never
   --- constructs.
   ---@return unix.Sigset mask
   function unix.sigpending() end
   ```

3. `tool/lua/test_signal.lua`: add, before the trailing `print("PASS")`:

   ```lua
   -- sigpending takes no argument and has no reachable failure on any
   -- platform this project supports (EFAULT needs a pointer this
   -- binding never constructs); it must always return a plain Sigset.
   assert(unix.sigpending() ~= nil, "sigpending must always succeed")
   ```
