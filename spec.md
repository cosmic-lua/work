## Evidence

Every fresh-context review run today (2026-09-05, twelve of them) cloned
cosmic-lua/work into a throwaway directory and ran `gitboard sync` against
it before reading anything. A cold clone has no `o/gh-cache`, so that
`sync` pays the full price GitHub charges: three lane reads plus two
calls per open review-stage item (three today), around ten counted calls,
plus a whole-board cache rebuild — where the same `sync` against the
product checkout's `o/board` costs about four calls and no rebuild,
because its ETag cache already holds every response. Twelve reviews
spent well over a hundred calls re-fetching what one checkout already had.

The briefs invite it. `_work/brieftext_review.tl:72` says "Do this from
your own fresh checkout — never reuse another agent's worktree" about
mutation testing, which is right for the PRODUCT tree, and the research
review's step 1 (line 137) says "a fresh read-only clone of `<REPO>`";
nothing says the BOARD is different. The board is `<PRODUCT_ROOT>/o/board`
(the same `GITBOARD_DIR` the product's `bin/gitboard` exports), its
read-only verbs are safe from any worktree, and the review's one mutation
— the verdict — already goes through the product checkout's
`bin/gitboard`. An orchestrator filling the brief has no sentence to point
a reviewer at, so it writes its own environment note telling the reviewer
to clone and sync.

## Change

1. `_work/brieftext_review.tl`: a short "The board" paragraph in the
   "Where to work" section of both review templates: the board is
   `<PRODUCT_ROOT>/o/board`; run every read-only verb (`show`, `next`,
   `find`, `brief`) against it with `GITBOARD_DIR=<PRODUCT_ROOT>/o/board`
   from any worktree; never clone the board for a review; the
   fresh-checkout rule is about the product tree under test. The verdict
   block already says where the one mutation goes.
2. The research review's step 1 says the same: the fresh read-only clone
   is of the PRODUCT repo `<REPO>`; the board reads run against
   `<PRODUCT_ROOT>/o/board`.
3. `_work/brief_test.tl` asserts both rendered review briefs name
   `<PRODUCT_ROOT>/o/board` as the board and contain "never clone the
   board".

## Non-goals

Changing how `bin/gitboard` locates the board; the builder brief (a
builder never needs the board at all); making read verbs refuse a
throwaway clone.
