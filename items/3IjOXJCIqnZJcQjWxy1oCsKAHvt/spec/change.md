This is a C-code change, NOT a docs-only fix (unlike its four `re.*`
sibling captures) — it is not blocked on `0YFj_out2` and can proceed
independently, since it belongs to fix class 1 (degenerate-input-only
→ raise candidate), not class 2 (tuple deviation).

1. In `tool/net/lgetopt.c`, convert each of the 11 `FAIL(...)` sites
   (lines 71, 73, 75, 81, 86, 93, 96, 100, 102, 106, 115 at
   `fd0884d9` — re-verify current line numbers before editing, since
   this file has not been touched by this census effort and may have
   drifted) from the `FAIL` macro (push `nil, msg`, return 2) to a
   raise: `luaL_argerror(L, <arg index>, "<message>")` or
   `luaL_error(L, "<message>")`, matching this repo's own contract
   convention for argument-shape violations (see this repo's own
   `AGENTS.md`, and the already-settled `path.join` precedent, #276).
   Pick `luaL_argerror` with the correct 1-based argument index where
   the violation names a specific parameter (most of the 11 do:
   `args` is argument 1, `optstring` argument 2, `longopts` argument
   3, and the per-entry longopt checks should still cite argument 3);
   fall back to `luaL_error` only where no single argument index
   applies.
2. Decide whether the `FAIL` macro itself should be removed (if
   `getopt.parse` was its only caller — check with
   `grep -rn 'FAIL(' tool/net/lgetopt.c`) or left in place for future
   use; state which, and why, in this item's own record.
3. Update `tool/net/definitions.lua`'s `getopt.parse` annotation
   (current lines 1628-1634, re-verify before editing) to drop the
   `nil, string? error` failure tuple entirely — after this fix, a
   well-typed call always returns a populated `getopt.Result`, so the
   honest signature is `@return getopt.Result result` with no nil
   admitted, per this repo's own AGENTS.md contract-shape rule ("when
   slot 1 of a declared return admits nil, slot 2 is the error — an
   annotation that deviates is a bug, and a contract change to conform
   is made deliberately, definitions.lua same commit").
4. Run `make -j$(nproc) o//tool/lua/test` and confirm it passes; add or
   extend a test exercising at least one of the 11 raise sites (e.g.
   the `args must be a table` and `longopts table too large` cases) to
   assert it now raises rather than returning `nil, err`.
5. Re-run the probe above; it should now raise a Lua error instead of
   printing `nil\t<message>`. Paste the new output.
6. Leave a note on this item naming `cosmic/flags/getopt.tl:89-95` and
   `cosmic/flags/parse.tl:117-120` as cosmic-side sites a follow-up item
   (filed separately, in the `cosmic-lua/cosmic` repo) can simplify
   once the binding can no longer return `nil` for these inputs — do
   not make that edit here, since it is a different repo, and cosmic's
   own guards are currently harmless dead code, not broken behavior.
