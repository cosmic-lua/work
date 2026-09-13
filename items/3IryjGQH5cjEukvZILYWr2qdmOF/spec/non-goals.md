Not touching `_work/gitfriction.tl`'s claim-attribution redesign —
it already works, already passed adversarial review, and does not
need `opener` to keep working; this item only makes the fact
available for whoever next needs it (a future spec, a future gate),
not a mandate to rewire the friction gate onto it. Not backfilling
`opener` on any existing item — every item filed before this change
keeps `opener = ""` forever, same as `verdict_spec`'s own documented
precedent ("'' on an item verdicted before the field existed —
unknown, which is not the same as unchanged, and nothing may be
concluded from it"). Not a `--session` override flag on `new` (unlike
`take`, which explicitly supports claiming under an named session for
recovery scenarios) — filing-authorship has no equivalent recovery
need identified, and adding one un-asked-for would let one session
misattribute a filing to another. Not touching `claim`/`builders`/
`speccers`/`reviewer`'s own shapes or semantics.
