## Evidence

Board item `MD7t_OaND`'s spec named `_work/brief.tl` (fix) and
`_work/brief_test.tl` (a new regression test) as its `## Change`. The
builder found `_work/brief_test.tl` at 499/500 lines — one line of
headroom, nowhere near the 7-8 lines the leanest possible new test in
the file's own established style would cost — and, per the brief's own
instruction ("if the Change's additions cannot fit under the 500-line
cap, STOP now"), correctly stopped: the code fix landed and gated green
in the worktree, but the item as a whole delivered nothing mergeable.
It had to be re-filed as a child question and dropped back to `todo`,
discarding the full 99k-token/43-call build as a non-delivery (the code
sits unpushed in an orphaned worktree). The same file's cap blocked two
more queued items in this session's own wave (`XsHJ_6fGm`, `WyFa_GL3c`)
from being pulled at all, and a second file (`_tool/doc/init_test.tl`,
491/500) caused a third item (`t5hA_ZnKG`) to be skipped rather than
risk the same outcome.

The brief's instruction treats "doesn't fit under the cap" as
equivalent to "the spec's Change is impossible" — a hard STOP with no
middle path. But the two-line question a STOP always raises (split
the capped file, or place the new coverage in a sibling file) is
usually answerable without a full respec cycle: this codebase already
has files that exist SPECIFICALLY as an overflow sibling of a capped
one (e.g. `_build/nil_flow.tl` proposed as a possible split target for
`_build/nil_returns_test.tl` in item `0LDT_eyE3`'s own spec), and a
builder who has just read the capped file in full is often the
best-positioned reader to see the seam.

## Change

`_work/brief.tl`'s builder-brief step 1: when a Change-named file is at
or within a few lines of the 500-line cap, give the builder two options
before an unconditional STOP:
1. If the file has an obvious, low-risk split seam (a self-contained
   group of test cases, a section already separated by a comment
   header) and the spec's Non-goals don't forbid touching the file's
   shape, split it and land the new coverage in the new sibling file —
   name the split explicitly in the PR body as a deviation from the
   literal file list.
2. If no safe seam is obvious, or the split itself would be a
   judgment call bigger than the item's own scope, STOP as today —
   this remains the right answer for a genuinely ambiguous split.

Either way the builder reports which path it took and why, so a
reviewer judges the split the same way any other diff gets judged
(least surprise, no gratuitous restructuring) rather than the item
silently losing a build cycle to a binary fit/doesn't-fit check.

`_work/brief_test.tl`: a case with a Change-named file just over the
cap and an obvious split seam, asserting the brief instructs the split
path rather than a bare STOP.

## Non-goals

Not removing the STOP path — a genuinely ambiguous split still needs a
human/refiner call. Not changing the spec-bar-side proposal already
filed (`AY6h_bM0B`, flagging a near-cap file at refinement time before
an item is ever offered to a builder) — that's the earlier, cheaper
place to catch this; this item is the fallback for when it still
reaches a builder anyway.

## Access

cosmic-lua/work, read and write on a branch; no other repository.
