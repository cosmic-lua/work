## Evidence

`_work/store.tl` is at its cap. On main before cosmic-lua/work#18 it was
491 lines (`wc -l _work/store.tl`); #18 («cwi5_ntHB») lands it at exactly
500, and its builder reported spending about fifteen edit-and-measure cycles
compacting prose and encoding a three-field lease as one string purely to
fit. The two remaining read-path reductions that item targeted (folding the
load's three `cat-file --batch` passes into one; memoizing `remote get-url
origin` on the store) were dropped for the same reason, and the mutation-path
item «5x5P_O61f» needs the store to hold one snapshot and one load across a
write — more state on the same record. Every further process reduction runs
through this file, and it has no room.

`grep -n "^local function\|^--- " _work/store.tl | wc -l` shows how much of
the file is doc prose versus code; `grep -n "^local function" _work/store.tl`
lists the functions to split by concern.

## Change

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

## Non-goals

Any process reduction (those are «5x5P_O61f» and the batch-merge item, which
this unblocks); renaming any function; changing any verb's output.
