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
