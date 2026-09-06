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

`_build/cast_sites.tl`, `reconcile`: after the exact-key pass, a
second pass per file carries classes across a pure line shift. For
each path, collect the ORPHANS (committed rows whose `path\tline` no
scanned site matched, in line order) and the NEWCOMERS (scanned sites
with no class, in line order). When the two lists have the same
length, pair them in order and give each newcomer the orphan's class;
the row is written at the newcomer's line. When the lengths differ,
carry nothing for that file — the newcomers stay in the `unclassified`
list exactly as today, and the orphans drop, so a real addition or
removal is still surfaced. No text matching: a pure shift preserves
order and count, and that is the whole test.

`_build/cast_sites_test.tl`: three fixture cases under `TEST_TMPDIR`
with a two-cast source file and a committed tsv — (1) insert a line
above both casts: both classes carried, tsv lines +1, `unclassified`
empty; (2) add a third cast: the two originals carried by exact key,
the new one unclassified, no carry (lengths 1 vs 0); (3) delete one
cast and insert a line: lengths 2 orphans vs 1 newcomer — nothing
carried, one unclassified, one dropped. The doc comment at line 7-9
(`--reconcile` "carries the class forward for every site that still
exists") states the shift rule in one sentence.

`docs/design/casts.md`, wherever the reconcile command is documented
(`grep -n reconcile docs/design/casts.md`): one sentence — a pure line
shift keeps its classes; only a changed cast count in a file asks for
a class.

Gate: `bin/cosmic --make ci`.

## Non-goals

No new tsv column, no cast-text fingerprinting, no change to
`_build/casts.tl`'s per-file count baseline.
