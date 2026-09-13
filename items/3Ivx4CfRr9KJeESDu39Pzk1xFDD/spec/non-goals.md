Not deciding to do this — a decision this size (replacing a
CI-gating tool's core structural analysis) goes through `decide`
(`skills/decide/SKILL.md`) once the dependency lands and someone scopes
it for real, not through this item alone. Not touching
`cosmic/format` now. Not assuming the AST approach nets out simpler
before someone actually measures a spike against real files the way
the `cosmic.ast` spike itself was measured before being proposed as a
real module — this item's job is to make the option visible and name
its dependency, not to pre-judge the tradeoff.
