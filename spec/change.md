- `tool/net/definitions.lua`: for each line above whose C function
  returns through `SysretBool`/`SysretInteger`-style failure (confirm
  per binding in `third_party/lua/cosmo/lunix.c`; the twelve share
  five functions: rename/link overloads, fcntl, bind, setsockopt,
  connect, pledge), rewrite the arm's return list to the primary's
  shape, e.g. `---@overload fun(fd: integer, unixpath: string): true|nil, string?, unix.Errno?`.
  An arm whose C path genuinely cannot fail keeps `true` and gains a
  one-line comment saying why.
- `make -j$(nproc) o//tool/lua/test` passes (the annotation-coverage
  ratchet reads these lines).
- No C change, no contract change: the tuple shape is what the code
  already returns; only the annotation moves.
