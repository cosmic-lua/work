## Goal

Migrate GitBoard's brief rendering off its own hand-rolled placeholder
substitution and onto `cosmic.template`'s build-time compiled, typed
renderers. GitBoard currently reimplements what a stdlib module already
does; the two are meant to converge rather than live side by side
indefinitely.

## Evidence

Inspected `cosmic-lua/work` at `a43d1824cd5d48408b780f2ac16a3b42e0c5cd38`:

- `_work/brief.tl` implements `fill` via
  `text:gsub("<(%u[%u_]*)>", ...)`, `unfilled` via a separate scan, and
  `survivors` by checking declared tokens against a string-keyed value
  map. `cmd_brief` assembles that map, chooses the template, renders
  it, and reports missing values.
- `_work/brieftext.tl` and `_work/brieftext_review.tl` hold the
  builder, research, refine, decompose, full-review, and
  mechanical-review templates as plain string constants;
  `_work/brieftext_friction.tl` supplies an appended section.
- `grep -rn "cosmic.template" _work/*.tl` in this checkout: zero hits.
  No caller of `cosmic.template`/`template.compile` exists anywhere in
  GitBoard's own source.
- `cosmic-lua/cosmic` at `6e91fabe2e2c2c6bde2ff5a54d123e48cc702a26`
  exposes `cosmic.template.compile(src, name)`: template text declares
  a nominal Teal input record and compiles to Teal source exporting
  `render(d): string`. Plain-text mode (no HTML `Safe*` escaping) is
  the right mode for these Markdown briefs. Its public contract has no
  declared-field-metadata or partial-render API today — an API
  difference from what GitBoard needs, not yet proof a new API is
  required; see the companion cosmic-side item for that investigation.

This is duplicated template machinery, not a runtime bug: existing
board work has already fixed the absent-vs-empty and literal-token
survivor behavior in the custom implementation
(`«S4pF_DMGT»`, `«Kfl8_Jtao»`); this item is about retiring the
custom mechanism those fixes are patching, not about a new defect.

## Change

Migrate the six brief templates to build-time compiled
`cosmic.template` renderers with typed context records, keeping every
GitBoard-specific concern in GitBoard: context resolution, role
selection, missing-field policy, receipt checks, and reporting.
`cosmic.template` supplies text rendering only.

Start with an ordinary `*_gen.tl` that compiles the templates and
feeds the emitted Teal into GitBoard's existing strict build — verify
first that the GitBoard's pinned Cosmic release supports the required
compiler and build integration. Do not add a runtime template compiler,
and do not load or evaluate spec/item text as template source (a
spec's prose is DATA spliced into a rendered field, never itself
compiled).

Explicitly model the distinction the custom implementation already
draws: an absent value (leave its caller-fill token, report it as a
survivor), an intentionally empty value, and supplied text. A
misspelled template field must fail generated-code type checking; an
intentionally unresolved field remains a supported brief output — do
not regain missing-field reporting by scanning the rendered body (that
is the exact mechanism `«imyM_e1xz»` and the `WyFa_GL3c` regression
line landed to get away from).

## Acceptance

- All six brief variants (builder, research, refine, decompose, full
  review, mechanical review) use generated, type-checked renderers in
  a cold build and in the packaged GitBoard binary; editing a template
  invalidates its generated output.
- Golden/parity cases preserve brief body bytes, whitespace, appended
  sections, and missing-field ordering, with deterministic inputs for
  session labels and paths.
- Cases cover: absent vs. empty context fields; prepared vs.
  unprepared builder context; both review variants; and inserted
  spec/context text containing literal `<SPEC>`, `<CONST_NAME>`,
  `{{.field}}`, percent signs, and Markdown fences — inserted content
  stays verbatim and is never reinterpreted as template syntax.
- An unknown typed field fails the build with a useful template
  source location.
- The custom rendering implementation (`fill`/`unfilled`/`survivors`
  in `_work/brief.tl`) is removed once parity is established; only
  application-specific unresolved-value policy remains.

## Sequencing and existing work

Board item `«BxOU_xeG0»` already proposes position-declared `.tmpl`
build support in cosmic, explicitly waiting on a real consumer and
evidence that handwritten generators are repetitive. This migration
*is* that real consumer, using an ordinary hand-written `*_gen.tl`
first; automatic `.tmpl` discovery is not a prerequisite here and
should not be duplicated into this item.

Reconcile current state with in-flight items touching the same files
during implementation, rather than silently changing their contracts:
`«Kfl8_Jtao»` (literal-token survivor handling), `«imyM_e1xz»`
(review round-context regression coverage), `«3aE2_amFS»` and
`«AP77_4XCs»` (repo-specific command wording in the templates),
`«S4pF_DMGT»` (BOUNCE_CONTEXT blanking).

The companion cosmic-side item (probing and closing `cosmic.template`
gaps this migration surfaces) is filed separately in
`cosmic-lua/cosmic`; feed proven gaps there and consume the resulting
capability back here.

## Non-goals

No change to brief prose, claim or receipt authority, review-kind
selection, CLI output conventions, or board format. No HTML escaping
for these Markdown briefs. No new `cosmic.template` API added directly
in this item — that path runs through the companion cosmic-side item,
with an executable probe proving the gap first.

## Access

cosmic-lua/work, read and write on a branch.
cosmic-lua/cosmic, read only (consuming `cosmic.template`'s public
API and, via the companion item, any capability it gains; no write
there from this item).
