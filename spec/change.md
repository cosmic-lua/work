Two doc-comment sentences, no code:

1. `cmd_new`'s doc comment gains: "Mints a fresh id; a caller that needs a
   chosen id (a fixture, a replay) builds the `item.Item` and calls
   `store.save` directly — see `_work/storeinit_test.tl`'s `seed_one_item`."
2. `init_repo`'s doc comment gains: "…for a board with nothing filed. A
   clone of a populated origin still needs `publish.sync` before its
   `refs/heads/items/*` exist locally; the verbs' `--dir` path assumes it
   ran."

`bin/cosmic --make ci` passes unchanged; no test is added for prose.
