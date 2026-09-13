Add ONE new entry to `3p/tl/tl_patch/narrow.tl`, in the same file, same
`Edit` record shape, and same sorted-name-ordering convention every
other entry there follows. Name it `narrow-pcall-zero-return`.
`file = "tl.lua"`. `find` must be this exact block (confirmed to occur
exactly once in `o/3p/tl/tl.lua`, inside `special_pcall_xpcall`, via
`grep -c "table.insert(rets.tuple, 1, bool)" o/3p/tl/tl.lua` → `1`):

    find = [=====[      local rets = self:type_check_funcall(fnode, ftype, b, argdelta + base_nargs)
      if rets.typename == "invalid" then
         return rets
      end
      table.insert(rets.tuple, 1, bool)
      return rets
   end]=====]

`replace`: the same block, with an `any`-typed slot 2 appended ONLY when
`rets.tuple` was empty before the `boolean` was inserted (i.e., the
callee's own declared return arity is 0) — carrying an explanatory
comment in the style of this file's other entries:

    replace = [=====[      local rets = self:type_check_funcall(fnode, ftype, b, argdelta + base_nargs)
      if rets.typename == "invalid" then
         return rets
      end
      -- cosmic carried patch: a callee that declares zero return values
      -- (e.g. unix.Memory:write/:store) leaves pcall typed as a bare
      -- `boolean` -- one value, no error slot at all -- so
      -- `local ok, err = pcall(f, ...)` fails to compile even though the
      -- call is exactly the honest-failure shape this codebase writes
      -- everywhere else. Add an any-typed slot 2 ONLY on this exact
      -- path (arity>=1 callees already get their own real declared
      -- return types here, untouched, which is correct and needs no
      -- widening).
      local had_no_rets = #rets.tuple == 0
      table.insert(rets.tuple, 1, bool)
      if had_no_rets then
         table.insert(rets.tuple, a_type(node, "any", {}))
      end
      return rets
   end]=====]

`note` field: a one-line summary, e.g. `"pcall on a zero-return callee
compiles: an any-typed error slot 2 is added only when the callee's own
declared return arity is 0"`.

No change to `cosmic/shm.tl`: both call sites (lines 146, 171) already
compile clean under this patch WITH their existing `as (boolean, any)`
casts left in place (verified above — no "redundant cast" warning), so
leave them exactly as they are. (Removing the now-technically-redundant
casts is a valid future cleanup but is out of scope here — it is a
separate, optional change with its own tradeoff, not a needed part of
this fix, and touching it risks conflating "the patch works" with "the
casts are gone" in one diff.)

Add one test to `cosmic/teal_test.tl`, in the same canary style as
`test_narrowing_canary` (same file, lines 73-154): write a Teal snippet
declaring a function with return arity 0, calling it via
`local ok, err = pcall(f, ...)` and using both `ok` and `err`, check it
with `teal.check_file`, and assert `result.ok` — this is the canary
`_build/coldbuild_test.tl`'s cold-build rule needs (see
`AGENTS.md`'s "The cold-build rule"): the pinned release's checker,
without this repo's own patch, must NOT accept this snippet, and a tl
pin bump that moves the anchor must fail this test rather than a
hundred downstream type errors, exactly as the file's existing header
comment for `test_narrowing_canary` describes for the other narrow-*
entries.
