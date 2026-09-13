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
