`_work/brieftext.tl`'s `BUILDER` template, builder-brief step 1: when a
spec's Evidence asserts a BEHAVIOR ("X refuses Y", "Z is unreachable",
"the check fires when...") rather than a static fact (a line count, a
file's existence), the step explicitly requires reproducing that
behavior against the current tree before writing any code — not just
re-running `wc -l`/`grep -c` on cited lines. A premise that doesn't
reproduce is the same class of blocker as a Change that can't fit under
the file cap: STOP, report exactly what was tried and what happened
instead, and do not build against the unverified claim.

`_work/brieftext_test.tl`: a case asserting the rendered brief's step 1
names both re-running measured commands and reproducing described
behavior, not just the former.
