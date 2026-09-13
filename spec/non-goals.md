- **Do not commit a checker change.** `3p/tl/tl_patch.tl` gains no new
  edit key, `_make/patch.tl` is not touched, and the prototype from
  step 2 lives and dies inside `o/`. The only edit to
  `3p/tl/tl_patch.tl` is the one-word comment fix in step 10.
- **Do not fix a single flagged site.** Every site the census finds is
  a follow-up slice's work. A diff that guards even one of them is
  scope creep, and the census would then describe a tree that no
  longer exists.
- **Do not touch `cosmic/teal_narrowing_test.tl`.** Its
  `test_nil_union_is_admitted_outside_an_index` asserts today's
  boundary on purpose; it changes in the slice that moves the
  boundary, never in the one that measures it.
- **Do not edit the doctrine.** AGENTS.md, `docs/stdlib.md` and
  `docs/guides/checking.md` describe the gap accurately while the gap
  is open. Step 6 QUOTES the lines a strict mode would retire; it does
  not delete them.
- **Do not bump the `tl` pin.** `3p/tl/tl_pin.tl` stays at 0.24.8; a
  census measured against one tl and a patch audited against another
  is two facts that cannot be compared.
- **Do not touch `whilp/cosmopolitan`.** Nothing here reaches the C
  boundary or `definitions.lua`.
- **Do not open a teal-language/tl issue or PR in this slice.** Step 7
  writes the recommendation down; acting on it is a follow-up slice, so
  that the upstream text is reviewed here before it is published.
- **Do not add a cast, a `-- cast:` line, or a coverage exclusion.**
  This diff is two documents, one data file and one comment word.
- **Do not hand-write, edit or extend `nil-flow-sites.tsv`.** It is the
  strict binary's output, sorted; a line added or corrected by hand is
  a fabricated measurement, and the file exists precisely so a reviewer
  need not take the document's word for anything.
