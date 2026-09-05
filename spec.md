## Evidence

The builder of «98RT_EE0A» (the perf fixture, cosmic-lua/work#17) lost two
rounds to comments that stop one sentence short, reported in that build's
friction section (2026-09-05):

1. `_work/gitgraph.tl`'s `cmd_new` always mints `id = ksuid.new()`; nothing
   in its doc comment says a caller wanting a chosen id must build an
   `item.Item` and `store.save` it directly (the pattern
   `_work/storeinit_test.tl`'s `seed_one_item` uses). The builder read the
   verb's body to find out.
2. `_work/store.tl`'s `init_repo` doc says a fresh repo "needs nothing else",
   which is true only for a board with nothing filed: a clone of a populated
   origin still has empty `refs/heads/items/*` until `publish.sync` runs, so
   every verb answers "no item matches". One failed smoke round to find.

Measure before editing: `grep -n "ksuid.new" _work/gitgraph.tl` and
`grep -n "needs nothing else" _work/store.tl` locate the two comments.

## Change

Two doc-comment sentences, no code:

1. `cmd_new`'s doc comment gains: "Mints a fresh id; a caller that needs a
   chosen id (a fixture, a replay) builds the `item.Item` and calls
   `store.save` directly — see `_work/storeinit_test.tl`'s `seed_one_item`."
2. `init_repo`'s doc comment gains: "…for a board with nothing filed. A
   clone of a populated origin still needs `publish.sync` before its
   `refs/heads/items/*` exist locally; the verbs' `--dir` path assumes it
   ran."

`bin/cosmic --make ci` passes unchanged; no test is added for prose.

## Non-goals

Changing `cmd_new` to accept an id; changing `init_repo` to sync.
