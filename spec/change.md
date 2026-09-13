Split `_work/store.tl` by concern into two modules with no behaviour change,
so the next two items have room:

1. `_work/store.tl` keeps the `Store` record, `open`/`init_repo`, the ref
   snapshot (`list`, the digest, the one-shot lease from #18) and the
   `load`/`resolve` readers — the read half.
2. `_work/storewrite.tl` (new) takes the write half: `save`, `add_pending`,
   the lease/CAS bookkeeping around `publish`, `read_specs` if it is only a
   write-side helper (check its callers: `grep -rn "read_specs" _work/*.tl`).
   `store.tl` re-exports nothing; callers that used the moved functions
   change their `require` line, and the sweep is
   `grep -rln "store\.\(save\|add_pending\)" _work cmd`.
3. Both files end at or under 400 lines (`wc -l`), leaving the room the
   follow-ups need; state the two counts in the PR description.
4. Tests move with their functions: `_work/store_test.tl` splits into
   `store_test.tl` and `storewrite_test.tl` along the same line. The suite
   passes unedited otherwise, and `.cosmic-coverage` gains the new file's
   row by hand (never `--baseline`).
