Not re-opening «S4pF_DMGT»'s builder-kind fix — that landed and is
correct; this is the sibling call site it deliberately did not touch. Not
changing `survivors()`, `briefcontext.need`, or `bounce_context()` itself.
Not auditing the remaining brief kinds (`review`, `refine`, `decompose`)
for the same shape — if one of them has it, file it rather than widening
this diff.
