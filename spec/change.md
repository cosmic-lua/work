Bring `unix.wait`'s declared and actual return shape to the canonical
`T|nil, err string, errno?` used by every sibling in this family. The
concrete fix is an implementation decision for whoever picks this up
(candidates: return a single record on success the way this repo's own
binding-contract rule already prefers for multi-field successes elsewhere,
or document the flip explicitly and leave the C behavior as-is) — this
capture's job is to state the deviation with evidence, not prescribe the
fix. Any contract change is bound by AGENTS.md's rule: `definitions.lua`
updated in the same commit as the C change, landed as its own PR, never
folded into unrelated work, with the matching cosmic-side type regen and
wrapper fix following as cosmic's own change.
