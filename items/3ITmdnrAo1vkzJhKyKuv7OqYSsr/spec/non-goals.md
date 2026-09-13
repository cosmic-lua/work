- **No change to how a candidate release is judged ELIGIBLE.** The
  `git merge-base --is-ancestor <feature-sha> <tag sha>` check, and the
  question of whether the tag sha is the sha the binary was built from,
  belong to item **3ITx1Gtr** and must not be touched, restated, or
  pre-empted here. This slice answers "does this binary carry the
  rule", never "is this the right binary to consider".
- **No pin bump.** `bin/cosmic.pin` is not edited.
- **No patch changes.** `3p/tl/tl_patch/**` and `_make/patch.tl` are
  untouched; no new entry, no entry renamed.
- **No per-entry probe corpus.** One worked example fixture only — not
  a probe for each of the 32 entries, and no requirement that entries
  declare probes.
- **No binary self-description.** Do not add a flag, payload, or
  manifest that makes a built cosmic report the patch entries it
  carries. That is a larger design and is not this slice.
- **No new CLI flag and no new `--make` verb.** The tool is a script
  run under a built binary, like `_perf/run.tl`.
- **No edit to `_build/coldbuild_test.tl`**, and no change to any
  existing verdict-line format.
- **No board-item edits.** Correcting the completed items 3ISVlHT6 and
  3ISPGV8z is board state, not a pull request, and completed items are
  history.
- **No release.yml or other workflow changes.**
