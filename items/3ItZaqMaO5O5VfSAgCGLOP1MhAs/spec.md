## Evidence

Found by the research agent for `3ItPDqwHGFWcpT6psDoCCB2BBra` («CCB2_BBra», prose
near-duplicate signal research) while building a hand-labelled TRUE/CONTROL fixture
of prose blocks from the live tree.

At least 6 `_eval/checks/*.tl` files share a verbatim, byte-identical 3-line
`@param`/`@return` doc-comment block on their `check(workspace: string): integer,
{string}` entry function: `contained-task.tl:16`, `multi-module-build.tl:39`,
`text-report.tl:29`, `sqlite-indexer.tl:11`, `module-tests.tl:22`, `json-cli.tl:19`,
`child-tcp.tl:57`. Measured bm25 self-ratio between these pairs is ≈1.00–1.04 —
indistinguishable, by any textual signal (exact or near-duplicate), from a genuine
copy-pasted-and-drifted doc comment.

This is very likely a deliberate, correct convention (a shared function-shape
contract across parallel eval-check modules — `_eval/checks/` implements one
interface repeatedly, each file its own scenario), not a copy-paste defect. But the
sibling item building the EXACT-duplicate prose gate ("prose dupes: a zero-tolerance
gate over identical doc-comment blocks and markdown paragraphs") will hit this
pattern on day one: 6+ files, byte-identical blocks, is exactly its target shape.

## Change

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

## Non-goals

Restructuring `_eval/checks/*.tl`'s actual check logic — only the shared doc-comment
header is in question. Deciding the gate's general near-duplicate policy (a separate,
broader question already closed not-adopt for signals A/B by «CCB2_BBra» itself).
