A new claim shape must be taught to TWO places or it is accepted by one and
rejected by the other, and nothing says so where a builder would look.

Measured while adding the `handoff` action: the shape passed
`_work.stateclaim`'s `prepare` and was then rejected by
`_work.snapshot_validate`, with a message from a THIRD function
(`claim.renew_refusal`) because a holder change at the same claim id looks like
a renew. Cost: ~6 tool calls tracing a refusal whose text named none of the
three files.

The same split later hid a real hole: `snapshot_validate` judged the commit's
author while the claim being installed could name anyone, because the admit
side re-derives policy independently and had not been given the binding.

This is the design, and correctly so — `_work/workflow_rules.tl` now carries
the comment explaining that a published snapshot is validated independently of
whatever composed it. What is missing is that a builder learns it by being
bitten.

Document it where a claim change is made: a paragraph in
`_work/stateclaim.tl`'s header naming `_work/snapshot_validate.tl`'s
`claim_rules` as the admitting half, stating that any new `Action` or claim
shape needs a matching case there, and that the two should share one predicate
in `_work/workflow_rules.tl` rather than each spelling the rule out.
`handoff_refusal` is the worked example.
