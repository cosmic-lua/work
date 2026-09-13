**Amended after PR #1755's review (2026-09-06):** pairing orphans to
newcomers by count and line order can assign the WRONG class when two
casts in one file change relative order (the reviewer's repro: classes
silently swapped, `unclassified` empty) — a wrong class is worse than a
blank one, which is the module's own rule (`_build/cast_sites.tl:14-16`).
The mechanism is therefore text identity, not position:

`_build/cast_sites.tl`, `reconcile`: after the exact-key pass, for each
file with both ORPHANS (committed rows no scanned site matched) and
NEWCOMERS (scanned sites with no class), read the file's COMMITTED
text with `git show HEAD:<path>` (through `cosmic.proc`; when git is
unavailable or the path is untracked, carry nothing for that file) and
take each orphan's line from it, whitespace-trimmed. A newcomer whose
current line, trimmed, is byte-identical to exactly ONE orphan's line
inherits that orphan's class at the newcomer's line number; a newcomer
matching zero or several orphan lines stays unclassified, and so does
every newcomer whose trimmed line matches an orphan that ALSO matches
another newcomer (uniqueness holds on both sides: one orphan text, one
newcomer text, or nothing is carried); the unmatched orphans drop,
exactly as today. Order and counts are never
consulted, so a reorder cannot swap classes, and an edit to the cast
line itself (a real change) asks for a class again.

`_build/cast_sites_test.tl`: fixtures under `TEST_TMPDIR` are git
repositories (`git init`, commit the source and the tsv, then edit the
working tree): (1) insert a line above two casts — both classes
carried at the new lines, `unclassified` empty; (2) swap the two
casts' order with distinct line text — each class follows its text,
not its position; (3) two casts with IDENTICAL line text, one shifted —
ambiguous, carried nothing, both unclassified; (4) edit a cast's line
text and shift it — unclassified, the old row dropped; (5) a file not
under git — nothing carried; (6) one committed cast whose exact line
now appears on TWO lines of the working tree — neither carried, both
unclassified. The module doc comment (lines 7-9) states
the text rule in one sentence.

`docs/design/casts.md`, at the `--reconcile` description: one sentence —
a cast whose line text is unchanged keeps its class across a move; an
edited cast line asks for its class again.

Gate: `bin/cosmic --make ci`.
