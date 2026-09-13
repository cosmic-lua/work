Two files. `cosmic/coverage/init.tl`, its cast, and the casts
baseline are NOT touched — that is 3ISPGV8z, blocked on this landing
and reaching the pin.

1. **`3p/tl/tl_patch.tl`, header**: replace the header comment
   (lines 1–28) with exactly these 22 lines — same content, 6 lines
   freed for the entry:

   ```
   -- The carried patch riding 3p/tl/tl_pin.tl; _make/patch.tl is the
   -- mechanism. Each entry's `note` says what it does; a multi-line
   -- replacement also carries its reasoning at the lines it changes.
   --
   -- The ast-cache-* group (whilp/cosmic#967) lets an embedder skip tl's
   -- parse of its embedded prelude/stdlib d.tl sources — ~11 of the ~16 ms
   -- a fresh process pays in its first tl.new_env(). `ast-cache-hooks-*`
   -- exposes the node/type metatables and the typeid allocator a thawed AST
   -- needs; `ast-cache-new-env` (plus the -tl-tl twin for gentl's ground
   -- truth) accepts pre-parsed programs in EnvOptions, byte-identical when
   -- absent — generated in _types/tlast_gen.tl, thawed in cosmic/_teal_ast.tl.
   --
   -- The narrow-* group teaches the checker that a nil union narrows
   -- through the guards Lua programmers actually write — truthiness,
   -- `assert`, `x and x.field`, `== nil`, exiting branches, disjunctive
   -- guards, `x or fallback` with a non-nil fallback — each strictly
   -- better: more correct programs check, none stop. `narrow-nil-union`
   -- installs the shared helpers; the census is docs/design/nil-flow.md.
   --
   -- Carried, not forked: each anchor must match the pinned source exactly
   -- once, so a tl pin bump that moves this code fails the fetch loudly
   -- until the patch is re-audited (or dropped, once upstream lands it).
   ```

2. **`3p/tl/tl_patch.tl`, entry**: add one 6-line entry to the
   `narrow-*` group (directly above `narrow-nil-union`, today line
   377 after the header change), the reasoning carried by `note`
   since the replacement is a one-line type-declaration swap:

   ```
     ["narrow-pack-n"] = {
       file = "tl.lua",
       note = "mixed-arity table.pack fallback returns PackTable<any>: .n stays integer",
       find = [=====[      pack: function(any...): {any:any} --[[needs_compat]]]=====],
       replace = [=====[      pack: function(any...): PackTable<any> --[[needs_compat]]]=====],
     },
   ```

   Copy the six-space indentation inside the brackets byte-exactly —
   the find must match once.

3. **`cosmic/teal_narrowing_test.tl`**: one appended test,
   `test_mixed_pack_keeps_n_integer`, called after its `end`: write a
   probe file whose mixed `table.pack(coroutine.resume(t))` result
   assigns `.n` into a declared `integer` AND passes it as
   `table.unpack`'s third argument, and assert `teal.check_file`
   reports ok, quoting the errors in the failure message. Follow the
   file's existing probe pattern (`fs.write` into `TEST_TMPDIR`,
   `teal.check_file`, message with `table.concat(msgs, "; ")`).

4. **Ratchet**: none expected — no cast moves, no file joins or
   leaves coverage. If one complains anyway, run exactly the regen
   command its failure message prints and commit the result.
