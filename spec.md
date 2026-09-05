## Evidence

`_work/spec.tl` (165 lines, requires only `cosmic.hash`) has two
functions with zero board coupling despite the file's "spec bar"
framing:

- `sections(body)` (lines 42-56): given any markdown text, returns a map
  from lower-cased heading text to that section's non-blank lines,
  joined — any heading level (`#` through `######`) matched
  case-insensitively, a thematic break (`---`) ending the current
  section. Nothing in the function body references specs, items, or
  gitboard vocabulary.
- `ready_gaps(body)` (lines 64-73): given a list of required heading
  names, reports which are missing or hollow (present but with no
  non-blank line before the next heading). Parameterized entirely by
  `READY_SECTIONS` — today `{"Change"}` — with no heading name hardcoded
  in the function itself.

Independent confirmation this generalizes: `_work/overlap.tl`'s
`change_section` (lines 45-59) is a near-verbatim duplicate of
`sections`, narrowed to one hardcoded heading — its own doc comment
even says so ("the same heading-scanning `_work.spec.sections` runs for
the spec bar, narrowed to the one heading this module reads") without
the two ever being unified. That duplication is filed separately as its
own gitboard-internal finding; it's evidence here that the mechanism is
reached for twice inside one codebase already.

No such helper exists in cosmic today: `grep -rli "heading\|## .*section"
cosmic/*.tl` (2026-09-05) returns nothing markdown-structural.

Named `cosmic.headings` rather than `cosmic.markdown` deliberately:
«h6OJ_bQ48» already claims that name for a full lowdown-bound
parser/renderer, a much larger undertaking. The two are complementary,
not competing — this ships a small, already-proven regex-based scanner
now; a real AST-based parser landing later could subsume it (or not —
a cheap heading-section scan may still be worth keeping even once a
full parser exists, the way `cosmic.uuid` and the filed `cosmic.ksuid`
coexist rather than one replacing the other). Whoever builds either
should read the other's spec first.

## Change

1. `cosmic/headings.tl` (or wherever fits): port `sections`
   near-verbatim as a generic markdown heading-section scanner, and
   `ready_gaps` generalized to `required_sections(body, names)` (or
   similar) taking the required heading list as an explicit argument
   rather than a module constant.
2. Tests: port the existing coverage over heading levels, thematic
   breaks, and hollow-section detection.
3. `cosmic --docs` entry and module description, with an example use
   case (a doc linter, a PR-template checker).

## Non-goals

`spec.tl`'s GitHub-URL-slug extraction (`github_urls`/`reached_repos`/
`declared_repos`) — narrower and GitHub-specific, not clearly a stdlib
fit on its own; `spec.tl`'s `revision` (a pure git-blob-hash function) —
that belongs with the already-filed git plumbing module («teX8_bEiz»),
not here, since it's about git object hashing, not markdown; gitboard's
own spec-bar semantics (`READY_SECTIONS = {"Change"}`, the `## Access`
convention) — those stay in `_work/spec.tl`, built on the published
module once this migrates.
