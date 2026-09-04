## Evidence

`HlNE_YWL2` ("graph: require repo/base explicitly on new --parent and
attach, and refuse brief's silent base guess") names `_work/gitgraph_test.tl`
as one of three files gaining new test cases (its step 6: at least four new
assertions — a `new --parent` refusal, an `attach`-with-no-flags refusal,
an `attach --repo --base` success, and an `attach`-reusing-existing-values
success). Measured 2026-09-04 in a fresh worktree off `origin/board`:
`_work/gitgraph_test.tl` is at exactly 500/500 lines, the hard cap
(`AGENTS.md`/CLAUDE.md: "file length: ≤500 lines, no exceptions... enforced
by `cosmic --check lint`"). Zero headroom — a single added line fails the
cap. `HlNE_YWL2`'s own spec does not mention a split or restructure, so its
builder correctly stopped rather than improvising one
(`build-HlNE_YWL2-e1847cac`, no PR, clean worktree).

## Change

A refiner's call, not a builder's: either (a) split
`_work/gitgraph_test.tl` — e.g. extract the `attach`-focused test cases
(existing ones plus `HlNE_YWL2`'s four new ones) into a new
`_work/gitgraph_attach_test.tl` alongside the existing `_work/gitgraph.tl`
module — or (b) relocate `HlNE_YWL2`'s new `attach`/`new --parent` test
cases to a different, less-full test file if one already covers the same
surface. Whichever shape is chosen, write it into `HlNE_YWL2`'s own spec
(a `## Change` amendment naming the split/relocation explicitly) so its
next builder has a literal instruction rather than a blocker to
rediscover.

## Non-goals

Not a general policy for near-cap files — that is `AY6h_bM0B`'s scope
("spec bar: flag a Change-named file already within ~20 lines of the
500-line cap"), already filed. This item is the one concrete unblock
`HlNE_YWL2` needs.
