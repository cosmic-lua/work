Whichever module performs the tree-wide prose walk for duplicate/near-duplicate
detection (the exact-duplicate gate's own walk, and any future near-duplicate
report) excludes `CLAUDE.md` explicitly, or dedupes files by realpath before
extracting blocks — either is sufficient since the two paths are 100% content-
identical by construction (D-level project convention, not incidental). Add a
regression case: the walk's own test fixture asserts `CLAUDE.md` and `AGENTS.md`
are not both walked (or that a symlink's target is walked at most once tree-wide).
