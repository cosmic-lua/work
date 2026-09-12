## Goal

Use GitBoard's brief-template migration as the real-consumer evidence
that decides what `cosmic.template` is still missing, and close each
proven gap as its own `cosmic.template` change — rather than letting
GitBoard grow a second, parallel template engine to work around a gap
nobody has confirmed is real.

## Evidence

Consumer and companion item: `cosmic-lua/work#103` (migrate GitBoard's
six brief variants off custom placeholder substitution onto
`cosmic.template`). Inspected that checkout at
`a43d1824cd5d48408b780f2ac16a3b42e0c5cd38`:

- `_work/brief.tl` implements template substitution, declared-placeholder
  discovery, and reporting of unresolved fields by hand. An absent
  field stays visible for the caller to fill, an empty field is
  resolved, and inserted spec/context text must remain byte-exact even
  when it happens to resemble template syntax (`<CONST_NAME>`,
  `{{.field}}`).

- `cosmic.template` inspected at `6e91fabe2e2c2c6bde2ff5a54d123e48cc702a26`
  exposes `cosmic.template.compile(src, name)`, which emits typed Teal
  with `render(d): string` in text mode. Its public API does not
  expose declared-field metadata or a partial-render result. This is
  an API difference, not yet proof a new API is necessary: typed
  context preparation and existing conditionals may already cover some
  of what GitBoard needs.

## Change

Write executable, GitBoard-shaped probes against `cosmic.template`'s
current public API to establish which of the following it already
meets cleanly, and which need a reusable capability addition:

- partial rendering (an absent field renders as something the caller
  can still find and fill, rather than the compile/render step
  refusing outright)
- absent-vs-empty values (the same distinction GitBoard's `fill`
  already draws)
- declared-field inspection and unresolved-field diagnostics (so a
  consumer can report what's missing without re-scanning the rendered
  body)
- literal inserted text that happens to look like template syntax,
  staying verbatim and never reinterpreted
- reusable sections (GitBoard appends the same friction-log section to
  every brief kind)
- generator-to-packaged-module integration (an ordinary `*_gen.tl`
  compiling templates into a strict, type-checked build, per work#103's
  approach)

For every requirement the probe proves is a real gap — not merely a
usage pattern GitBoard hasn't tried yet — implement a concrete
`cosmic.template` change: the failing consumer probe first, then the
public contract, tests, and documentation. Feed each resulting
capability back into `cosmic-lua/work#103` as it lands, rather than
batching everything behind one release.

## Non-goals

Do not require GitBoard to retain a parallel template engine, or
duplicate generic parsing/scanning in GitBoard, merely to avoid
touching `cosmic.template`. Do not weaken `cosmic.template`'s
compile-time type checking or its HTML `Safe*` guarantees to add
partial rendering — any partial-render feature must be explicit,
never a global relaxation of required-field checking. Do not evaluate
inserted user/spec text as template source at any point. Do not
duplicate `«BxOU_xeG0»` (position-declared `.tmpl` build support,
already filed and explicitly waiting on real-consumer evidence) — link
build-integration friction observed here to that item instead of
re-filing it.

## Acceptance

A requirement-to-probe report distinguishes already-supported
behavior from confirmed gaps; every confirmed gap has either landed
support or a specific, linked follow-up item with its reproduction
evidence. GitBoard's migration (`cosmic-lua/work#103`) completes using
only the public `cosmic.template` API, with no second generic template
engine surviving in GitBoard. Literal template-looking data,
missing/empty fields, and typo diagnostics are all covered by tests.

## Access

cosmic-lua/cosmic, read and write on a branch.
cosmic-lua/work, read only (the consumer whose real templates and
migration drive this item's probes; no write there from this item).
