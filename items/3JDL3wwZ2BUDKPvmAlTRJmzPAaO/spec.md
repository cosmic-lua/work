## Evidence

`cosmic-lua/work`'s `_work/` test suite is large — 832 `test_*` functions
across 113 `_work/*_test.tl` files as of `df6227a2` (counted via
`grep -rc 'local function test_' _work/*_test.tl | awk -F: '{s+=$2} END{print s}'`)
— and several concrete signals this session suggest some of that size is
duplicated coverage, not just breadth:

1. `f6YD_gyJi`'s builder (board item, landed as PR #123) found
   `_work/store_test.tl`, `_work/storewrite_test.tl`, and
   `_work/storeref_test.tl` each carried a near-identical, independently
   re-implemented fixture helper for the same starting repo shape — a
   signal (not proof) that their actual test *cases*, not just their
   setup code, may overlap in what they exercise.
2. `_work/storeref_test.tl` was itself already split once before, from
   `_work/store_test.tl` (per that file's own history/header), and later
   split again into `_work/storeref_processcount_test.tl` for
   `f6YD_gyJi`'s parallelism fix — three files now share lineage from one
   original, raising the question of whether each retained cases still
   worth keeping separate versus cases that ended up asserting the same
   fact via different fixtures.
3. The claim/ancestry surface alone has at least five separate files —
   `gitclaim_test.tl`, `gitclaim_base_test.tl`, `gitclaim_stale_base_test.tl`,
   `gitclaim_batch_object_test.tl`, and the newly-added
   `gitclaim_handover_ancestry_test.tl` (board item `QIyT_gwRr`) — each
   independently exercising some slice of "does `claim` compute the right
   base." Plausible each earns its place (different failure mode per
   file), but this is exactly the shape worth an actual audit rather than
   an assumption either way.

This item does not itself claim any specific pair of tests IS redundant —
that determination needs a real pass reading actual assertions, which
this item's Change section commissions.

## Change

Audit `_work/*_test.tl` for test CASES (not fixture helpers — those are
already being consolidated separately, e.g. via `f6YD_gyJi`) that assert
the same fact about the same code path, via a different fixture or
file, with no distinguishing edge case between them. Concretely:

1. Group test files by the module/verb they exercise (the claim/ancestry
   cluster named above is one candidate group; there are others — survey
   broadly, don't stop at the first group found).
2. Within each group, read every test function's actual assertions (not
   just names) and classify each pair of similarly-named or
   similarly-shaped tests as: (a) a genuine duplicate — same input shape,
   same code path, same assertion, no distinguishing case; (b) looks
   similar but exercises a real distinct edge case (keep, and if the
   distinguishing case isn't obvious from the test's name, rename it so
   it is); (c) unclear — leave a note rather than guessing.
3. For every genuine duplicate found (category a), remove the redundant
   one and keep the clearer/better-named survivor — never remove a case
   whose edge is even plausibly distinct; a "maybe" is category (c), not
   (a).
4. Report a table: file, test name, classification, action taken (kept /
   removed as duplicate of X / renamed / left as unclear-for-follow-up),
   plus before/after test-function counts and the coverage-stage wall
   time before and after (same `rm -rf o/.coverage` discipline as
   `f6YD_gyJi`'s builder used, to avoid a stale-cache false reading).

## Non-goals

Not a license to weaken, thin, or remove a test to make numbers look
better — this repo's own convention (see `optimize` skill, and this
session's own amended `f6YD_gyJi` spec) treats "weaken a check for
speed" as a bar violation, not a valid technique. A test kept under
category (b) or (c) stays exactly as strict as it is today. Not
touching fixture-setup code (`_work/fixture.tl`,
`_work/commit_flow_fixture.tl`, etc.) — that consolidation is
`f6YD_gyJi`'s scope, already landed. Not required to resolve every
category-(c) case in this same item — filing a follow-up item per
unclear cluster, with the specific tests named, is an acceptable
outcome for those.

## Access

cosmic-lua/work, read and write on a branch; no other repository.
