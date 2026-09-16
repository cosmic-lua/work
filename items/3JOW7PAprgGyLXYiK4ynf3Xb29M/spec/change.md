The review brief instructs a reviewer to mutation-test a guard the change
adds or preserves, with no branch for a diff that adds no code guard at all —
a doc change, a prose change, a pin bump. Two reviewers this session invented
or nearly invented a ritual target to satisfy the instruction, and both did
the right thing only after a caller's note told them they could decline.

A mutation test on a guard that does not exist is worse than none: it
produces a green line in a report that means nothing, and a reviewer who
learns to manufacture one learns to manufacture the rest.

Give the template an explicit branch. When the diff adds or preserves a guard,
mutate it as today. When it does not, say so plainly in the verdict and say
what was checked instead. Prefer mutating a guard the whole commit depends on
over inventing one for the diff.
