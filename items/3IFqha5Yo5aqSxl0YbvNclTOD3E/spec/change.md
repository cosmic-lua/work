Add one function to `cosmo.cov` and teach `CovHook` the count event.
All of it is in `tool/net/lcov.c`, `tool/net/definitions.lua`, and
`tool/lua/test_cov.lua`.

**`tool/net/lcov.c`.**

- Add a `long budget` field to the existing `g_cov` state struct, 0
  meaning "no budget".
- Add `LuaCovBudget` and register it in `kLuaCov[]` as `{"budget",
  LuaCovBudget}` — first entry, keeping the table's alphabetical order.
  Its contract:

  ```
  // cov.budget(n) -> boolean
  //
  // Arms an instruction budget on the calling thread's collection: the
  // hook raises "cosmo.cov: instruction budget exceeded" once n VM
  // instructions have executed. n nil or 0 clears it. Returns false,
  // changing nothing, when this thread's hook is not the collector's —
  // the caller then falls back to its own debug.sethook budget.
  ```

  Implementation: `luaL_optinteger(L, 1, 0)`; if
  `lua_gethook(L) != CovHook`, push false and return 1. Otherwise store
  the value in `g_cov.budget` and re-arm the calling thread with
  `lua_sethook(L, CovHook, LUA_MASKLINE | (n > 0 ? LUA_MASKCOUNT : 0),
  (int)n)`. Re-arming is what restarts Lua's internal instruction
  counter, which is why each call gives a fresh budget rather than
  continuing the last one. Push true and return 1.
- In `CovHook`, replace the leading
  `if (ar->event != LUA_HOOKLINE) return;` with: on `LUA_HOOKCOUNT`,
  re-arm the thread line-only (`lua_sethook(L, CovHook, LUA_MASKLINE,
  0)`) so the budget is one-shot and does not fire again while the
  error unwinds, clear `g_cov.budget`, then
  `lua_pushliteral(L, "cosmo.cov: instruction budget exceeded")` and
  `lua_error(L)`; on any other non-line event, return as before.
  Counting a line hit is unchanged.
- Extend the file's header comment block (`:25-40`) with a sentence on
  the budget: the collector's hook can carry one so a caller that needs
  an instruction budget does not have to take the slot.

**`tool/net/definitions.lua`.** Add the `cov.budget` annotation beside
the other six, in the same style: a `@param n integer?` (VM
instructions until the hook raises; nil or 0 clears), a
`@return boolean` (false when this thread's hook is not the
collector's), and a line naming the raised string verbatim —
downstream compares it, so it is a frozen value like any other error
string at this boundary.

**`tool/lua/test_cov.lua`.** Add three cases, in the file's existing
plain-`assert` style:

- a budget arms and fires: `cov.start()`, `cov.budget(10000)`, then
  `pcall` a chunk that loops forever; assert the pcall returned false
  and the caught value is exactly
  `"cosmo.cov: instruction budget exceeded"`.
- collection survives it: after that pcall, `cov.running()` is still
  true and `cov.snapshot()` holds hits for the looping chunk — the
  budget is one-shot, not a stop().
- it refuses a foreign slot: with a `debug.sethook` Lua hook installed
  instead of the collector's, `cov.budget(10000)` returns false and
  `debug.gethook()` still reports that foreign hook.
