## Problem

`_build/cast_sites.tl`'s `--reconcile` keys a recorded cast site on
`path\tline` (`_build/cast_sites.tl:116-140`), so any edit that shifts
a line carrying an `as` cast reads as a newly discovered, unclassified
site: the tool refuses to write rather than carry the existing class
forward. The `_build/cast_sites_test.tl` failure message advertises
`bin/cosmic --make run _build/cast_sites.tl --reconcile` as the regen
command, but from the shifted state that command cannot produce the
correct file — it is exactly the case it declines to guess at.

Evidence, from building batch 6/7 of the runner-mode migration
(PR #1556, 2026-08-30): deleting 404 bare `test_*()` self-call lines
from 20 `cosmic/*_test.tl` files shifted six rows in
`docs/design/cast-sites.tsv` naming sites in `log_test.tl`,
`rand_test.tl` and `searcher_test.tl`. `--reconcile` refused. The
builder verified the cast text at each new line was byte-identical to
the old one (a clean one-to-one map), moved the six rows by hand
carrying each class forward verbatim, and re-ran `--reconcile`, which
then succeeded and reproduced that file byte-for-byte — so the
committed inventory is provably what the tool generates, and nothing
was reclassified.

This will recur. The tree-migration container (3IOCdooE) has six more
line-deleting batches, and other in-scope `*_test.tl` files carry
recorded casts, so each batch hits the same refusal and each agent is
told by the failure message to hand-classify sites that are already
classified and merely moved. The likely fix: key `reconcile` on the
cast line's CONTENT (or a content hash) rather than its line number,
or fall back to content when the line-number lookup misses, so a pure
line shift regenerates through the advertised command. Scope and shape
are unmeasured — this item needs refinement to the spec bar before it
is pullable.

## Evidence (2026-09-06, orchestrator re-measure)

Two builders paid this in one pass: «Hkal_OAFy» (cosmic#1750) spent
~6 calls checking whether a cast-site row had to move, and «iltX_EM90»
(cosmic#1753) shrank a comment in `cosmic/fs/find.tl`, which shifted
three casts' line numbers; `_build/cast_sites.tl --reconcile` dropped
their classes and the builder re-entered them by hand. The mechanism:
`_build/cast_sites.tl:116-133` keys the committed inventory by
`path .. "\t" .. line` (`class_of[...]`, line 123) and looks each
freshly scanned site up by the same key (line 128), so a site whose
line moved is `unclassified` and its old row is silently dropped.
`scan` (line 77) yields `{path, line}` only; the tsv
(`docs/design/cast-sites.tsv`, header `path\tline\tclass`) carries no
text. `wc -l _build/cast_sites.tl` → 204, `_build/cast_sites_test.tl`
→ 131.

## Change

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
matching zero or several orphan lines stays unclassified, and the
unmatched orphans drop, exactly as today. Order and counts are never
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
under git — nothing carried. The module doc comment (lines 7-9) states
the text rule in one sentence.

`docs/design/casts.md`, at the `--reconcile` description: one sentence —
a cast whose line text is unchanged keeps its class across a move; an
edited cast line asks for its class again.

Gate: `bin/cosmic --make ci`.
## Non-goals

No new tsv column, no cast-text fingerprinting, no change to
`_build/casts.tl`'s per-file count baseline.
