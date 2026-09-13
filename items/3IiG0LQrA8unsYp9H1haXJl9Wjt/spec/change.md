Classify and, if a change is warranted, propose one of:
1. Keep the shape but make it an explicit, named exception to the
   `T|nil, err string, errno?` convention (documented in the
   binding-contract-shape rule in `AGENTS.md`), since it is long-standing,
   load-bearing, and used by every fetch-shaped binding consistently
   between `Fetch` and `FetchStream`; or
2. Normalize by returning a single failure-info value in slot 2 (e.g. a
   record `{message, kind}`) instead of overloading slots 2 and 3 by
   branch, and updating cosmic's wrapper + generated types in lockstep,
   as its own change (never inside an optimization, per this repo's own
   `AGENTS.md` "Conventions" section).

Land any actual contract change with a matching `definitions.lua`
annotation change in the same commit and a cosmic-side type regen +
wrapper fix as its own follow-up PR.
