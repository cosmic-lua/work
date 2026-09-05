## Access

read access to `cosmic-lua/work` — `_work/tail.tl`, `_work/cachequery.tl`
and the merged PR #22 diff cited below in Evidence.

## Evidence

PR #22 (`3It7RFOgaN9ROO8gehRGkFkU7L5`, «GkFk_U7L5», merged 2026-09-05) added
two independent resolution paths for a handle tail: `_work/cachequery.tl`'s
`resolve_tail` (cache-first) and `_work/tail.tl`'s `resolve_glob` (the
git-glob fallback). The item's own spec required both to refuse an
ambiguous tail with "the same ambiguity message" the pre-existing
`tail.resolve(all, input)` path already uses.

A fresh-context review of the merged PR (independent checkout, PR head
`ee10b105`) found the two new paths do not actually agree with each other:

- `_work/tail.tl`'s `resolve_glob` (~line 182, ambiguity check ~line 209)
  joins the full ~27-character **ids** of the colliding matches into its
  refusal message.
- `_work/cachequery.tl`'s `resolve_tail` (~line 145) joins the
  **tails** (`«XXXX_XXXX»`-shaped) of the colliding rows into its refusal
  message — matching the pre-existing `tail.resolve` shape.

So the same failure mode (two items sharing a tail) produces a
different-shaped refusal string depending on whether the cache answers
(tails) or the glob answers (full ids), and the glob path's shape is a
literal deviation from the item's own "same ambiguity message" acceptance
bar. Practically rare — tails were measured collision-free across all 930
refs on the live board at spec time — but real, and it leaves the two new
code paths inconsistent with each other as well as with the message the
spec asked them to match. The review posted this finding on the merged PR
(https://github.com/cosmic-lua/work/pull/22#issuecomment-5548698182)
before it could gate the (already-merged) diff.

## Change

Make `_work/tail.tl`'s `resolve_glob` ambiguity refusal join the matched
**tails**, not the full ids, so both new paths (and the pre-existing
`tail.resolve` path) render the identical refusal shape for the same
input. Add a test case (in `_work/tail_test.tl` or `_work/gitboard_test.tl`,
wherever the existing ambiguity-refusal test already lives) that an
ambiguous tail refuses with the same message text regardless of which
path (cache hit vs. glob) resolves it.

## Non-goals

Re-litigating whether tails should be collision-checked at mint time (out
of scope — «GkFk_U7L5»'s own spec already treats this as unreachable in
practice); any other part of «GkFk_U7L5»'s merged diff, which review found
otherwise sound (fresh `bin/cosmic --make ci` green on the PR head, scope
matched the spec, a mutation test on the "never loads the whole board"
guard confirmed real).
