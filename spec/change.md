Handle resolution costs one `for-each-ref` at most and never a load; the
whole-board load happens once per run, in the verb that needs it.

1. `_work/gitboard.tl` `resolve_id`: the tail branch stops calling
   `store.list`. It calls `refs.for_each_ref(s.root, {"refs/heads/items/*"
   .. tail, "refs/heads/ended/*" .. tail})` with the tail normalized by
   `tail.tl` (divider and guillemets stripped, both chunks), takes the
   single match, refuses on zero (the same "no item matches" message as
   today) or on more than one (the same ambiguity message), and sets the
   same one-shot `fresh_lease` ticket from the matched ref and sha that the
   prefix path sets, so the load that follows skips its own `for-each-ref`.
   `store.tl` is NOT touched (the split item «Bkbr_5S1U» is reshaping it
   concurrently); the glob call lives in `gitboard.tl` or in `tail.tl` as a
   `tail.glob_patterns(tail) -> {string}` helper.
2. Case-folding: when the exact glob matches nothing and the input has
   letters, fall back to one `refs.for_each_ref` over the two namespaces
   with names only, case-fold in Lua via `tail.resolve` against the
   returned ids, and set the ticket from that row. Still one process, no
   content.
3. Cache-first: before either glob, when `o/board.db` exists, ask
   `_work.cachequery` for `SELECT id FROM items WHERE lower(id) LIKE '%'
   || lower(?)` (one small function beside `find`); a single hit resolves
   with ZERO processes and the ticket is set from the snapshot the verb
   takes anyway (the load's own `for-each-ref`); zero hits fall through to
   step 1 (the item may be newer than the cache); two or more hits refuse
   as ambiguous. Apply the same cache-first step to `store.resolve`'s
   prefix path ONLY if it can be done without editing `store.tl` (it
   cannot today — leave it, note it for after the split).
4. Tests: `_work/gitboard_test.tl` gains a case that resolves a handle
   with `store.list` swapped for a stub that fails the test if called
   (the load must not run for resolution), one that a mixed-case handle
   resolves through the fallback with exactly one `for_each_ref` call, and
   one that a handle for an item absent from the cache still resolves
   through the glob. The existing handle-lease test keeps passing.
   Expected for the builder's own strace check (not recorded): `show
   <handle>` equals `show <prefix>` (9 on the live board today), and 8 when
   the cache answers.
