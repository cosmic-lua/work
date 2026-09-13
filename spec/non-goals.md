Not widening pcall's declared return type again, scoped or unscoped —
confirmed twice now (this pass and the prior session) to break sites
tree-wide with no scoping mechanism available in `3p/tl_patch`. Not
filing the ok-keyed narrowing checker feature as a live item: no
concrete site needs it today (both named call sites already have a
working, idiomatic cast); revisit only if a future site's cast becomes
genuinely unwieldy, at which point it needs its own decision record
before implementation.
