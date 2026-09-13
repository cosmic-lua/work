- **No upstream change and no pin bump.** `3p/tl/tl_pin.tl`,
  `3p/tl/tl_patch.tl` and anything under `o/3p/` stay as they are: the
  under-typing is in OUR curation, not in tl.
- **Do not widen `KEEP` beyond `FILE`.** Every other name `erase` sends
  to `any` is an internal tl record or interface that this curation
  deliberately does not re-declare, and adding one silently freezes an
  upstream internal into our surface. One name, for the one reason
  stated.
- **Do not touch the other from-any sites.** `cosmic/fetch/init.tl`'s
  three belong to `3IQCrJpB`; `cosmic/fd.tl`, `cosmic/quicksand/proc.tl`
  and `cosmic/zip.tl` are not this slice's; and the occurrences in
  `_build/casts_test.tl`, `_cli/assert_lint_test.tl` and
  `_tool/lint_test.tl` are fixture text whose whole purpose is to be
  counted — editing them breaks the lints' own tests.
- **Do not remove or weaken the `fd ~= nil` guard**, and do not change
  `cosmic.teal.search_module`'s `string | nil` return.
- **No decision record and no doc prose.** The erasure rule's intent is
  already written at `_types/gentl.tl:14-16`; this makes the code match
  it.
- **Frozen:** `tl.d.tl` stays generated and uncommitted; the cast lint,
  its `-- cast:` grammar, and the baseline format are untouched.
