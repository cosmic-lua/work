Does not generalize the allowlist into a documented per-project
convention — `_build/casts_kinds.tl` stays this repo's own data, read
opportunistically off disk by a generic rule that no-ops when the file
is absent. Does not change `cosmic.ast`'s pattern grammar to
distinguish same-rendered-type collisions (the `explicit` list stays
the mechanism for those) — investigated and rejected in review as
disproportionate machinery for ~16 stable sites.
