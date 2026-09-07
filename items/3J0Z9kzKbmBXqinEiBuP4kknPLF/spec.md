## Evidence

PR #1793 (item «bUGM_XojW») removed the shrink-only ceiling and
zero-site check from the cast-kind ratchet — the `Kind` record's
`sites: integer` field and every `sites = N,` line in `_build/
casts_kinds.tl`'s `KINDS` table are gone, and `_build/casts_test.tl`'s
two ceiling-related tests are deleted. Both files' own file-header doc
comments still describe the removed mechanism verbatim: `_build/
casts_kinds.tl`'s header (~lines 24-27) still says "`sites` is the
shrink-only ceiling `_build/casts_test.tl` checks every kind
against... Deleting a kind's entry outright, once its last site
closes, is itself part of that shrink"; `_build/casts_test.tl`'s own
header (~lines 19-22) still says "checks three things... no kind
matches more sites than its committed ceiling... every kind still has
at least one site." Neither was in #1793's stated `## Change` file
scope (the `Kind` record's field/doc-comment and the `KINDS` table's
`sites = N` lines only), so the builder correctly left them untouched.

Consequence: `grep -c sites _build/casts_kinds.tl` still returns 7 (all
in this stale header prose, none in code) — the exact acceptance
illustration #1793's own spec quoted as `→ 0` doesn't reproduce,
because the count includes prose that describes a mechanism the code
no longer has.

## Change

Rewrite both header doc comments to describe only the mechanism that
now exists: `_build/casts_kinds.tl`'s header drops the shrink-ceiling/
delete-at-zero description of `sites`, since the field is gone; `_build/
casts_test.tl`'s header drops the "no kind exceeds its ceiling"/"every
kind has at least one site" bullets, describing only the remaining
exactly-one-kind classification check. `grep -c sites
_build/casts_kinds.tl` should return 0 once this lands, matching what
#1793's own spec expected.

## Non-goals

No further code change — this is a doc-comment-only cleanup. Not
retiring `_build/casts_test.tl` itself, which is the sibling item's
(`MsXN_oznh`) job once it lands.
