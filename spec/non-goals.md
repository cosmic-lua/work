- **No new lint for an orphaned justification.** `cosmic/compress.tl`'s
  two stale comments are deleted here, but nothing is added to stop the
  next one appearing — a `-- cast:` reason with no cast under it is a
  second, independent check with its own diagnostic and its own fixtures.
  Captured as board item `3IPFx8zM`; do not implement it in this diff.
- **`_cli/lint.tl`'s behaviour does not move.** `cast_lines`,
  `is_justified` and `check_cast_justification` are untouched; the only
  edit to that file is the two lines that export an existing local. No
  file's lint result may change.
- **The floor's format does not move.** `_build/casts_baseline.tl` stays
  one sorted `["path"] = count` entry per line, written and read through
  `_tool.floor`; `casts.baseline`, `casts.BASELINE` and `casts.TREES` keep
  their current signatures, because `_build/size.tl` requires this module.
- **Do not re-scope which trees are counted.** `TREES` and the
  `testdata/` skip stay exactly as they are; this slice changes what
  counts as a cast, not where the count looks.
- **Do not touch the sites the census now stops counting.** Beyond the
  two comment lines in `cosmic/compress.tl` named in `Change` 3, the
  quoted examples in `_build/casts_test.tl`, `_cli/lint.tl` and
  `_build/casts.tl`'s header are correct documentation and stay as they
  are.
- **Do not rewrite `docs/design/casts.md`.** It is a dated census against
  `d3e59de7`; correcting it is separate work, and this slice changes the
  instrument, not the record.
