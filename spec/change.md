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
