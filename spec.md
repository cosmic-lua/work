## Evidence

Blocks «zq2b_vYsf» ("gitboard drop/spec: a refusal on a minted claim says to
pass --session, not that the builder drops their own work"). Its builder
(build-zq2b_vYsf-62aa6405, 2026-09-04) measured, before any edit:

    $ wc -l _work/gitverbs.tl _work/gitgate.tl
    500 _work/gitverbs.tl
    500 _work/gitgate.tl

Both at the exact 500-line cap (`cosmic --check lint`, "no exceptions").
«zq2b_vYsf»'s own Change needs a minted-claimant regex check
(`^(build|review|research|refine|decompose)-`) plus a second, distinct
refusal-message string in each of two functions: the `drop` refusal
(`_work/gitverbs.tl`, `cmd_drop`, around lines 319-325 — the builder notes
the spec's evidence cited line 294, since shifted) and the `spec` refusal
(now `_work/gitgate.tl`'s `spec_refusal`, lines 114-126 — the spec's
evidence guessed `_work/gitverbs.tl` or `_work/gitclaim.tl`, neither of
which currently holds it; grep for the exact refusal string
`"REFUSED: %s is claimed by %s — rewriting another session's live build"`
to reconfirm before acting on this, in case it has moved again). Both
additions are genuine net-new lines (a condition plus a message literal),
so neither fits under the cap in either file as they stand today.

## Change

A refiner's call: read `_work/gitverbs.tl` and `_work/gitgate.tl` in full,
pick a concrete split or relocation for each that creates headroom for
«zq2b_vYsf»'s two-message change (e.g., extracting a shared
`minted_claimant_hint(claimant: string, base_message: string): string`
helper into a smaller file both `gitverbs.tl` and `gitgate.tl` require,
if that nets fewer total lines across the two callers than inlining twice
— or relocating unrelated functions out of one or both files into an
existing lower-line-count sibling). Whichever shape is chosen, write it
into «zq2b_vYsf»'s own spec as a `## Change` amendment naming the exact
file(s), function(s), and line ranges to move, so its next builder has a
literal instruction rather than a blocker to rediscover — mirroring how
«T6Gj_9ge9» resolved the identical class of problem for
`_work/gitgraph_test.tl`.

## Non-goals

Not a general policy for near-cap files in this tree (that is a
separate, already-filed scope — see «AY6h_bM0B», "spec bar: flag a
Change-named file already within ~20 lines of the 500-line cap"). This
item is the one concrete unblock «zq2b_vYsf» needs.
