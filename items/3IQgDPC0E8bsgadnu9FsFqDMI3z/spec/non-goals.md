- **No file outside this piece's tree.** The siblings own the rest;
  two diffs touching one file is the merge conflict this cut exists to
  avoid.
- **No `cosmic/time.tl`.** That file is board item 3IPXQcgW, with its
  own decided shape and its own blocker.
- **No `_test.tl`, `_example.tl` or `_benchmark.tl` file.** Those are
  the `check.must` sweep (3IPXQ1Zw and its children); a `check.must` in
  library code would throw and AGENTS.md forbids it.
- **No checker change.** `3p/tl/tl_patch.tl` and `_make/patch.tl` are
  untouched; this is edits at sites.
- **Do not widen a signature to `T | nil, string` without counting its
  callers.** A fallible return pushes the nil onto every call site;
  `grep -rn` the callers and record the count in the PR before choosing
  it over a guard.
- **Do not throw.** D23's exemption list is a rule, not an open
  licence: an `assert` is allowed only where the binding's declared
  `| nil` is unreachable for the arguments this call passes, and then
  it carries a trailing `-- assert: <why>` comment.
- **Do not add a cast.** `as` is not a fix for an unguarded union.
- **Do not rewrite `docs/design/nil-flow.md` or its `.tsv`.** They are
  a dated snapshot against `e7ac1580`; a later census re-derives them.
- **Do not commit the throwaway strict checker.** The Method builds it
  inside `o/` and deletes it; no edit to `o/3p/tl/tl.lua` rides with
  the PR.
