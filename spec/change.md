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
