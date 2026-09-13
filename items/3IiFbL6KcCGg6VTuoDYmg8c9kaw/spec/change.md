Bundle the 2-value success pair into one table return
(`{reader=…, writer=…}|nil, string?, unix.Errno?`), matching
`unix.capget`'s caps table, `unix.nanosleep`'s remainder table, and
`unix.getrlimit`'s `Rlimit` table, so slot 2 always means error
regardless of branch:

1. `third_party/lua/cosmo/lunix.c`, `LuaUnixPipe`: on success, push
   one table with fields `reader` and `writer` instead of two
   positional integers:

   ```c
   static int LuaUnixPipe(lua_State *L) {
     int pipefd[2], olderr = errno;
     if (!pipe2(pipefd, luaL_optinteger(L, 1, 0))) {
       lua_newtable(L);
       lua_pushinteger(L, pipefd[0]); lua_setfield(L, -2, "reader");
       lua_pushinteger(L, pipefd[1]); lua_setfield(L, -2, "writer");
       return 1;
     } else {
       return LuaUnixSysretErrno(L, "pipe", olderr);
     }
   }
   ```

2. `tool/net/definitions.lua`, same commit — add a new class and
   rewrite `unix.pipe`'s return block:

   ```
   --- A pipe's two file descriptors, as returned by `pipe`.
   ---@class unix.Pipe
   ---@field reader integer the read end's file descriptor
   ---@field writer integer the write end's file descriptor
   ```

   ```
   ---@return unix.Pipe|nil
   ---@return string? error
   ---@return unix.Errno? errno
   ---@nodiscard
   function unix.pipe(flags) end
   ```

3. Add or extend a test (wherever this repo's existing `unix.pipe`
   coverage lives — check first) asserting the new table shape on
   success and the clean 3-value tuple on failure (an `ulimit`-forced
   EMFILE, matching the evidence probe above, or an equivalent
   deterministic failure trigger).

No change to `unix.pipe`'s failure path — it already implements the
fork's standard `nil, error, errno` convention correctly.
