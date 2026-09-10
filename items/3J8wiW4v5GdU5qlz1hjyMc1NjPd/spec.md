## Evidence

The first review of `cosmic --diff OLD` correctly found that a handler-level
test bypassed literal CLI parsing.  Its request-changes report gave the
reproducer, but did not constrain the tempting repair.  The correction added
`Options.error_code`, which fixed the literal exit but crossed the pinned
checker boundary and required a second review round.  The final repair reused
the existing `Options.diff` marker and passed both contracts.

A high-reasoning reviewer is most valuable at the bounce when it predicts how
the obvious local fix can violate a distant invariant.  Today the review brief
requires a concrete finding and mutation but does not require that correction
envelope.

## Change

Extend only the request-changes guidance in `_work/brieftext_review.tl` so a
reviewer reports five labeled facts:

1. exact reproducer;
2. smallest permitted correction boundary;
3. the tempting unsafe repair, when one is visible;
4. the adjacent invariant that repair could violate; and
5. the focused regression plus every named boundary guard the corrected head
   must rerun.

The guidance must say not to design the implementation when no safe envelope
is established: name the uncertainty and let the rework builder bounce instead
of widening scope.  Preserve the existing adversarial posture, exact-head
verdict, and mutation requirement.  Add template assertions in
`_work/brieftext_test.tl` or the current review-brief test file.

At most two files and 80 changed lines.  Use the `Options.error_code` /
pinned-cold-build episode as a fixture only if an existing generic template
test cannot assert the required labels without product-specific prose.

## Non-goals

No automated patch design, no new verdict fields or storage format, no change
to GitHub review delivery, and no product-repository changes.

## Access

cosmic-lua/work, read and write on a branch.  Read-only access to the cited
cosmic item history.

