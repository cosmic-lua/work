Move the GRAPH verbs out; leave the PHASE verbs behind. This is the
same "split by subject" the module set already uses — `gitview` holds
the whole-board reads, `gitshow` the single-item read, `gitverbs` the
mutations — carried one level further.

1. **New `_work/gitgraph.tl`** carrying, moved VERBATIM (no logic
   changes, no renames, no reordering):
   - `cmd_new` (`_work/gitverbs.tl:45-109`)
   - `cmd_attach` (`:110-182`)
   - `cmd_block` and its `unblock` half (`:183-260`)

   These are the verbs that shape the GRAPH — a parent edge, a blocker
   edge, an item's existence — and roles derive from the graph, so
   they are one subject. Carry each function's doc comment with it,
   and carry over exactly the requires the moved code uses.

2. **`_work/gitverbs.tl` keeps** `cmd_init`, `cmd_spec`, `cmd_move`,
   `cmd_done`, `cmd_sync` — the phase crossings plus the two
   housekeeping verbs — and drops the moved names from its record and
   its returned table. Update its module doc comment to say what it
   now holds and to name `_work.gitgraph` as the other half.

3. **`_work/gitboard.tl`** requires the new module and points the
   `new`, `attach`, `block` and `unblock` dispatch lines at it
   (`grep -c 'verbs\.' _work/gitboard.tl` is 8 today; four of those
   move). `wc -l < _work/gitboard.tl` is 319.

4. **Tests follow their subject.** `_work/gitverbs_test.tl` is 479
   lines; move the cases that drive the moved verbs into a new
   `_work/gitgraph_test.tl`, carrying whatever fixture helpers they
   need. A test that drives BOTH halves (a decomposition that also
   asserts a phase) stays in `gitverbs_test.tl` and requires both
   modules — do not split a single test function.
