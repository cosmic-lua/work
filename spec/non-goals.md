Not a general redesign of the board's concurrency model — scoped to the
one place (review session labels) where two independent successful
`take`s on the same item are currently possible. Not addressing the
(much cheaper, already-tolerable) equivalent race on BUILD claims, which
this evidence did not observe causing wasted work in this pass.
