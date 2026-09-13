- No `3p/tl/tl_patch.tl` changes and no upstream `tl` proposal — this slice is a
  re-classification against the ALREADY-corrected narrowing rules (#1191), not new
  narrowing capability. A site that needs a patch to be removable is confirmed
  un-removable today and stays out of scope for a future, separately-sized wave.
- No change to `cosmic/teal_narrowing_test.tl` or AGENTS.md/docs/guides/checking.md —
  #1191 already corrected those; this slice does not touch narrowing documentation.
- No change to any file's logic beyond deleting a cast and its comment — a site that
  "almost" checks clean except for an unrelated nearby issue is left with its cast
  intact, not partially refactored.
