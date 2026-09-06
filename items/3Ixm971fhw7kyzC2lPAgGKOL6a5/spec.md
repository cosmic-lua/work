## Evidence

`_build/cast_sites.tl`'s first reconcile pass keys committed rows by
`path\tline` (the exact-match loop, lines ~176-191 after cosmic#1755).
Two casts in one file that swap positions while keeping the same set of
line numbers (cast A moves from line 1 to line 5, cast B from 5 to 1)
match each other's rows by line alone, so each inherits the OTHER's
class silently — the text-identity pass added in cosmic#1755 runs only
for rows the first pass left orphaned, and here nothing is orphaned.
Found by that PR's builder while writing its reorder fixture (its first
attempt, an in-place swap on lines 1 and 5, reproduced the swapped
classes and never reached the text pass). `wc -l _build/cast_sites.tl`
→ 322, `_build/cast_sites_test.tl` → 327 (after #1755).

## Change

`_build/cast_sites.tl`, the exact-key pass: an exact `path\tline` match
carries the class only when the committed line's trimmed text (read
through the same `git show HEAD:<path>` the second pass uses) equals
the current line's trimmed text; a same-line, different-text site is
treated as an orphan-plus-newcomer pair and falls through to the
text-identity pass like any other move. When git is unavailable or the
file is untracked, the exact-key pass keeps today's line-only behaviour
(no history to compare against, and a fresh tree is exactly the case
the committed tsv was reconciled on). `_build/cast_sites_test.tl`: one
git-backed fixture — two casts with distinct text swapped in place on
the same two line numbers — asserting each class follows its text; and
one asserting an unchanged file still reconciles byte-identically.
`docs/design/casts.md`: no change (the text rule sentence from #1755
already covers it).

Gate: `bin/cosmic --make ci`; `--reconcile` on the real tree must still
reproduce `docs/design/cast-sites.tsv` byte-for-byte.

## Non-goals

No change to the second pass or to the tsv format.
