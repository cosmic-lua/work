## Evidence

Found by the research agent for `3ItPDqwHGFWcpT6psDoCCB2BBra` («CCB2_BBra», prose
near-duplicate signal research) while building a whole-tree prose-block extractor.

`CLAUDE.md` at the repo root is a symlink to `AGENTS.md` (per AGENTS.md's own header:
"`CLAUDE.md` at the root is a symlink to this file"). A prose scanner that walks the
tree by filename and reads file CONTENTS without deduping by realpath will read
`AGENTS.md`'s entire body twice under two different paths, and every single paragraph
in it will report as a spurious 1.00-ratio "exact duplicate of itself."

Reproduced 2026-09-05: an early, uncorrected pass of the CCB2_BBra research agent's
extractor (before it added an explicit exclusion) produced roughly 50 spurious
`1.0000`-ratio pairs from this alone — noise large enough to dominate a naive
duplicate count.

This is a live risk for the sibling item that builds the EXACT-duplicate prose gate
(the "prose dupes: a zero-tolerance gate over identical doc-comment blocks and
markdown paragraphs" item, and its "19 exact groups" figure) — if its own tree walk
does not dedupe `CLAUDE.md`/`AGENTS.md` by realpath (or explicitly skip one of the
two paths), its reported duplicate count and its zero-tolerance gate will both be
inflated by this single symlink, every time, on every run.

## Change

Whichever module performs the tree-wide prose walk for duplicate/near-duplicate
detection (the exact-duplicate gate's own walk, and any future near-duplicate
report) excludes `CLAUDE.md` explicitly, or dedupes files by realpath before
extracting blocks — either is sufficient since the two paths are 100% content-
identical by construction (D-level project convention, not incidental). Add a
regression case: the walk's own test fixture asserts `CLAUDE.md` and `AGENTS.md`
are not both walked (or that a symlink's target is walked at most once tree-wide).

## Non-goals

Deduping OTHER symlinks in the tree generically (none are known to exist beside this
one; a generic realpath-dedup is welcome but not required beyond covering this case).
Changing which of `CLAUDE.md`/`AGENTS.md` is the symlink (settled, AGENTS.md's own
header).
