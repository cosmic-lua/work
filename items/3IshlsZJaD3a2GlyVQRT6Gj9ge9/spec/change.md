Split `_work/gitgraph_test.tl`, following the repo's own precedent
(`gitfriction_test.tl`, `gitowner_test.tl` above): create
`_work/gitattach_test.tl` as a new sibling test file.

1. Move these three functions out of `_work/gitgraph_test.tl` verbatim,
   each with its preceding doc comment, into `_work/gitattach_test.tl`:
   `test_a_reparent_survives_a_rebase`, `test_attach_refuses_a_cycle`,
   `test_attach_of_an_already_attached_pair_is_a_noop_success`. In today's
   file that is the single contiguous block from the line right after
   `test_decomposition_is_one_push_two_commits`'s closing `end` (line 44)
   through the closing `end` of the noop-success test (line 89) — collapse
   the double blank line the removal leaves behind to one. Leave
   `_work/gitgraph_test.tl`'s other 15 tests, requires, and header comment
   untouched (all still needed by what remains — do not drop any require).
2. Give `_work/gitattach_test.tl` a `#!/usr/bin/env cosmic` shebang, a
   header doc comment describing its scope as the `attach`/`new --parent`
   parenting-gate surface (both verbs share the one gate `HlNE_YWL2`'s own
   spec describes, `item.problems` — this file is not attach-only, it is
   "how an item gains a parent"), and a note mirroring
   `gitfriction_test.tl`'s: split from `_work/gitgraph_test.tl`, which sits
   against the file cap. Require only what the moved tests use: `check =
   require("cosmic.check")`, `graph = require("_work.gitgraph")`, `store =
   require("_work.store")`, `fixture = require("_work.fixture")`, `publish
   = require("_work.publish")` (needed by `test_a_reparent_survives_a_rebase`'s
   `publish.sync`), and alias from `fixture` only `init_shared`,
   `init_state_repo`, `root_with_leaf`, `file_item`, `commits` — an
   aliased-but-unused local fails `--check types` (warnings are errors), so
   do not copy `give_spec` or any other alias `_work/gitgraph_test.tl`
   still uses but these three tests do not.
3. `HlNE_YWL2`'s four new `attach`/`new --parent` gate test cases (its own
   step 6) land in `_work/gitattach_test.tl`, appended after the three
   moved tests — not in `_work/gitgraph_test.tl`, and not written by this
   item (see Non-goals). `HlNE_YWL2`'s other step-6 files
   (`_work/item_test.tl`, `_work/brief_test.tl`) are unaffected.
4. In the same session, repoint `HlNE_YWL2`'s own spec at the new
   location: read its current spec, and write it back with
   `gitboard spec HlNE_YWL2 <file> --base <file-with-its-current-spec>`,
   changing step 6's `_work/gitgraph_test.tl` reference for the four
   `attach`/`new --parent` facts to `_work/gitattach_test.tl` (the
   `_work/item_test.tl`/`_work/brief_test.tl` references in the same step
   are untouched). This is the literal instruction its next builder needs
   instead of a blocker to rediscover.
5. `cosmic --check lint` (file-length) and `cosmic --make test` must pass
   against both files after the split — this is the existing cap
   enforcement and the existing 18 tests, not a new check to add.
