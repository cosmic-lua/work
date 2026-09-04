## Evidence

`HlNE_YWL2` ("graph: require repo/base explicitly on new --parent and
attach, and refuse brief's silent base guess") names `_work/gitgraph_test.tl`
as one of three files gaining new test cases (its step 6: a `new --parent`
refusal, an `attach`-with-no-flags refusal, an `attach --repo --base`
success, and an `attach`-reusing-existing-values success — its other step-6
facts land in `_work/item_test.tl` and `_work/brief_test.tl`, untouched by
this item). Measured 2026-09-04 in this checkout (`wc -l _work/gitgraph_test.tl`):

```
500 _work/gitgraph_test.tl
```

Zero headroom — a single added line fails the cap
(`AGENTS.md`/CLAUDE.md: "file length: ≤500 lines, no exceptions... enforced
by `cosmic --check lint`"). `_work/gitgraph.tl` itself is not at cap
(`wc -l _work/gitgraph.tl` → `425 _work/gitgraph.tl`, 75 lines of headroom) —
only the test file is full. `HlNE_YWL2`'s own spec does not mention a split
or restructure, so its builder correctly stopped rather than improvising
one (`build-HlNE_YWL2-e1847cac`, no PR, clean worktree).

This repo already has the exact precedent to follow: `_work/gitfriction_test.tl`
and `_work/gitowner_test.tl` both carry a header comment saying they were
split out of `_work/gitgraph_test.tl` for this same reason (`grep -n
"gitgraph_test" _work/gitfriction_test.tl _work/gitowner_test.tl`):

```
_work/gitfriction_test.tl:6:-- from `_work.gitgraph_test`, which sits against the file cap.
_work/gitowner_test.tl:8:-- the sibling `_work/gitgraph_test.tl`'s file cap sends the graph
```

Both name the split-off file `_work/git<topic>_test.tl` — not
`_work/gitgraph_<topic>_test.tl` — and neither pulled `_work/gitgraph.tl`'s
source apart to match: `_work/gitclaim_test.tl` is the same pattern with no
matching `gitclaim.tl` source module at all, requiring `_work.gitverbs` and
`_work.gitverdict` directly (`ls _work/gitclaim.tl` → no such file; its
header requires only `_work.gitverbs`/`_work.gitverdict`). A test file
grouped by topic, independent of which source module implements that
topic, is the house convention here — not something this item invents.

`grep -n "^local function test_" _work/gitgraph_test.tl | wc -l` → 18 test
functions in the file today. Three are attach-focused — the ones an
`attach`/`new --parent` gate change belongs beside — spanning one
contiguous block, `sed -n '46,89p' _work/gitgraph_test.tl | wc -l` → 44
lines, immediately after `test_decomposition_is_one_push_two_commits`
(ends line 44) and immediately before the `block_and_capture` helper
(starts line 91):

- `test_a_reparent_survives_a_rebase` (with its 6-line doc comment) —
  uses `graph.cmd_attach` to resolve a lost push race
- `test_attach_refuses_a_cycle` (with its 1-line doc comment)
- `test_attach_of_an_already_attached_pair_is_a_noop_success` (with its
  2-line doc comment)

Together these three use, from the file's current requires: `check`,
`graph`, `store`, and from `fixture`: `init_shared`, `init_state_repo`,
`root_with_leaf`, `file_item`, `commits` (verified by reading each of the
three function bodies — none of the other 15 tests' requires, e.g.
`gitboard`, `verbs`, `intake`, `prio`, `decision`, `flow`, are touched by
these three).

## Change

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

## Non-goals

Not a general policy for near-cap files — that is `AY6h_bM0B`'s scope
("spec bar: flag a Change-named file already within ~20 lines of the
500-line cap"), already filed. This item is the one concrete unblock
`HlNE_YWL2` needs.

Not writing `HlNE_YWL2`'s four new test bodies: the behavior they assert
(`cmd_attach` taking `repo`/`base` parameters, `cmd_new`'s tightened
parent gate) does not exist until `HlNE_YWL2`'s own Change (its steps 1-4,
still `todo`) lands — a test for it would fail today. This item only opens
the file and the headroom they will land in, and repoints `HlNE_YWL2`'s
spec at it.

Not touching `_work/gitgraph.tl`: it has 75 lines of headroom today (see
Evidence) and none of its source moves — `cmd_attach`/`cmd_new` stay put;
only their tests are regrouped, matching `gitclaim_test.tl`'s precedent of
a topic-named test file with no matching source module.
