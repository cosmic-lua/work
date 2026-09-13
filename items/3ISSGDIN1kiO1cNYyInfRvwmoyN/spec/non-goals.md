No change to `["label"]`'s widen-all, to loop/while/if widening
(they pass their own nodes for a different question), to
`assigned_anywhere` itself, or to `widen_in_scope`. No nil-flow
strictness change: `T | nil` stays permissive outside indexes
(3IPXRRd2). No retiring of the coverage/benchmark idiom sites in
this slice (cold-build rule: source depending on the new rule waits
for a pin that carries it). Existing patch entries stay
byte-identical; `_make/patch.tl` untouched.
