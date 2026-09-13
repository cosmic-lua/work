- Not about the environment-line mismatch (a separate, harness-level
  issue outside gitboard) — only about `brief`'s own template naming a
  path it does not create.
- The `REVIEW` template's prose is unchanged. `_work/brieftext_test.tl`
  asserts `REVIEW` still contains `fresh checkout` (`:211`) and
  `<WORKTREE>` (`:213`), and that `REVIEW_SCRIPT` contains neither
  (`:199`, `:206`) and stays checkout-free. Those four assertions are
  a wall: they must pass untouched.
- Preparation receipts stay builders-only.
  `_work/preparation_receipt.tl:137` refuses `--receipt-out` with
  `--review` (`"--receipt-out supports builders only"`) and
  `_work/gitworktree.tl:306` refuses `--adopt` with it; teaching
  reviews to write a receipt (so `prep.worktree` could answer directly)
  is a larger change and not this one.
- `_work/gitworktree_test.tl:391-393`'s `refs/heads/<id8>` assertion is
  vacuous in the same way as the path assertions beside it, but
  asserting the real branch name needs a claim root the unclaimed
  fixture does not have. Leave it; it is its own item if anyone wants it.
- `worktree --review` itself is correct and does not move. Nothing in
  `_work/gitworktree.tl` changes except the two `path` expressions.
- No new verb, flag, or item field — `_work/gitcommands.tl`,
  `_work/gitboard.tl` and `_work/gitverbs.tl` are untouched. In
  particular `brief` gets no `--root`/`--repo-dir` of its own: on a
  board with no `gitboard.repository` mapping the placeholder survives
  for the caller, and closing that gap is its own item.

The guard this diff adds lives in `_work/brief_rework_test.tl`; the
two it repairs live in `_work/gitworktree_review_test.tl` and
`_work/gitworktree_test.tl`. Run one with `bin/cosmic --make test
_work/<file>`.
