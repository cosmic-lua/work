Not weakening what a BUILDER must do. Verification moves to the builder, it
does not disappear, and `help build`'s existing instruction to re-run before
building becomes load-bearing rather than advisory.

Not changing the review gate. A reviewer still checks the diff against the
tree and still mutation-tests; nothing here makes a review less adversarial.

Not removing `## Change` itself or the empty-Change refusal, which is the
one check that cannot go stale.
