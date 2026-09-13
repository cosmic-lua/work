1. **`3p/cosmos/cosmos_pin.tl`**: set `version` to
   `2026.08.26-1e1658153` and the `sha` to
   `ea7e05a6a13bb9e1f6b3d99829f0fd9639f069e7aa527976b59914748ec18001`
   (or a newer verified release per Evidence). Then `bin/cosmic
   --make fetch && bin/cosmic --make build` — the types regenerate
   from the new pin's embedded `definitions.lua`; nothing is committed
   under `o/`.
2. **`cosmic/time.tl`**: at the five clock sites, revert each
   three-line assert dance to the direct two-slot read
   (`local secs, nanos = unix.clock_gettime(unix.CLOCK_REALTIME)` and
   the MONOTONIC equivalents), deleting the `-- assert:` comments and
   the `secs_or_nil` renames. Signatures and doc comments stay: they
   already declare plain integers, which is now the binding's own type.
3. **`cosmic/fs/path.tl`**: the `join` wrapper body returns to
   `return cosmo_path.join(...)`; delete the assert and its comments;
   the doc comment keeps the sentence "Calling with no arguments, or
   with every argument nil, is a caller error and throws" — true as
   ever, the throw now comes from the binding. The routing of
   `walk.tl`/`find.tl`/`tree.tl` through this wrapper STAYS — one
   boundary for the binding is right regardless of its type.
4. **Tests stay.** `cosmic/time_test.tl`'s
   `test_clock_readers_return_integers` and `cosmic/fs/path_test.tl`'s
   `test_join_returns_a_plain_string` / `test_join_with_no_arguments_throws`
   pass unchanged (the no-args throw now originates in C; the test
   asserts `pcall` failure without matching the message). Update only
   their comments where they attribute the behavior to the D23 assert.
5. **Compare gate**: per the pin-bump procedure (cosmopolitan
   AGENTS.md), run the `_perf` compare against the previous pin —
   baseline on the old pin, current on the new, per the optimize
   skill's commands — and quote the gate verdict in the PR.
