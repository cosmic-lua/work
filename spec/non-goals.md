- **No `cosmic/**` file.** That half is the sibling item; two diffs
  touching one file is the merge conflict this cut exists to avoid.
- **No library file.** A `check.must` in library code would throw, and
  AGENTS.md forbids it. Only `_test.tl`, `_example.tl` and
  `_benchmark.tl`.
- **No checker change.** `3p/tl/tl_patch.tl` and `_make/patch.tl` are
  untouched; this is edits at sites.
- **Do not change what a test asserts.** The wrap makes the type
  honest; a test that passes today must still pass, testing the same
  thing, with the same number of assertions.
- **Do not add a cast.** `check.must` replaces `assert(x) as T`, never
  the other way round.
- **Do not rewrite `docs/design/nil-flow.md` or its `.tsv`.** They are
  a dated snapshot against `e7ac1580`; a later census re-derives them.
- **Do not commit the throwaway strict checker.** The Method builds it
  inside `o/` and deletes it; no edit to `o/3p/tl/tl.lua` rides with
  the PR.
