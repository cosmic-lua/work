- No edit to any file under `_work/` that is not one of the two test files:
  `_work/gitverbs.tl`, `_work/gitgate.tl`, `_work/flow.tl` and the rest of
  the sources stay byte-identical.
- No edit to `_work/fixture.tl`. Both halves keep using the shared fixture;
  do not fork it, and do not move `spec_file` into it — it is used by one
  half only.
- No test renamed, no assertion reworded, no test body changed, and no test
  added or deleted. A verbatim move is what makes this reviewable as a
  split rather than a rewrite.
- No new `_work/gitspec.tl` source module, and no move of `cmd_spec` out of
  `_work/gitverbs.tl`.
- No `.cosmic-coverage` edit, no `--baseline` run, and no change to
  `.github/workflows/**` or `.cosmicignore`.
- No third file, and no further splitting of either half.
