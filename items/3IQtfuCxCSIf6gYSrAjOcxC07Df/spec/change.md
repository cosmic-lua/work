1. **`tool/net/lpath.c`** (172 lines): make the all-nil branch raise
   exactly what the zero-arg branch raises. In `LuaPathJoin`, replace
   the `else { lua_pushnil(L); }` arm of the `gotstr` check (line
   108–111) so the function becomes:

   ```c
   if (gotstr) {
     luaL_pushresult(&b);
     return 1;
   }
   luaL_error(L, "missing argument");
   __builtin_unreachable();
   ```

   Interior-nil skipping and empty-string coercion are untouched — the
   loop above the branch does not change.

2. **`tool/net/definitions.lua`**, same commit: line 1688
   `---@return string?` becomes `---@return string`; rewrite the prose
   sentence pair (lines 1682–1685) to: "Specifying no arguments, or
   exclusively `nil` arguments, raises an error. `nil` arguments are
   otherwise skipped over. Empty strings behave similarly to `nil`,
   but unlike `nil` may coerce a trailing slash." `---@param str
   string?` and `---@param ... string?` stay — per-argument nil
   skipping remains part of the contract.

3. **`tool/lua/test_definitions_conformance.lua`** (515 lines), in the
   `=== failure shapes ===` section (line 372): add the raise-shape
   pins beside the existing failure probes:

   ```lua
   assert(not pcall(path.join), "join() must raise")
   assert(not pcall(path.join, nil), "join(nil) must raise")
   assert(not pcall(path.join, nil, nil), "join(nil, nil) must raise")
   assert(path.join("") == "", "join('') stays the empty string")
   assert(path.join("a", nil) == "a", "interior nil still skipped")
   ```

   The happy-path probe at line 252 stays and now verifies a plain
   `string` slot. No slot-observation entry is needed: the binding no
   longer declares an error slot to fill.
