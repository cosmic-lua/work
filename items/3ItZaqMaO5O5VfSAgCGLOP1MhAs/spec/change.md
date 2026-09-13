Before or as part of landing the exact-duplicate prose gate, decide and record
explicitly how it treats this pattern — one of:
(a) an allowlist/convention exemption for `_eval/checks/*.tl`'s shared entry-point
doc comment (or more generally, doc comments proven identical because they document
an interface CONTRACT rather than incidental prose), documented in the gate's own
header or test data; or
(b) accept the flag and require the 6+ files to de-duplicate the doc comment (e.g.
state it once on the package/interface and let each `check` reference it, if the
language/doc-tooling allows), if the gate's authors judge zero-tolerance should mean
zero-tolerance even for interface boilerplate.
Either way, the gate's own test suite gets a fixture case pinning the decision, so a
day-one failure on this exact pattern doesn't block that PR's own review.
