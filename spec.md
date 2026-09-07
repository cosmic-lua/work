## Evidence

The original 2026-09-05 observation was broader than the current surface. Since
then, `show --todo 0` has landed and lists every pullable todo item, so the old
claim that there is no way to remove bare `show`'s eight-row cap is no longer
true. Re-measured 2026-09-07 against `810ad912`:

- `gitboard show --todo 0` removes the eight-row display cap, but only for the
  board-wide pullable-todo rendering. It does not list all todo items, select
  `doing`/`triage`/`ended`, filter by parent or band, or change `show ID`.
- `gitboard find TEXT...` remains capped at 20 BM25-ranked matches and mixes
  states. It has no `--state`, `--parent`, `--band`, `--limit`, or `--all`.
- `show ID` remains one combined prose report: fields, bar findings, spec, and
  history. It has no `--field`, `--section`, `--raw`, or `--json` output.
- Multiple IDs cannot be queried together. `show` accepts one optional ID, and
  a caller comparing six candidate items must issue six commands and parse six
  prose reports.

This was encountered directly while checking whether six workflow findings
already had board coverage. The efficient question was a small projection over
several records: ID, title, state/resolution, and relevant snippets. The actual
path was repeated FTS queries followed by individual `show ID` calls whose full
specification and history dominated the output. One candidate, `RSTv_DYmH`
itself, returned more than a page when only its role and state were needed.

The absence of structured output also made a false inference easier: search
hits were mistaken for current gaps until each item was opened and its
`resolution` checked. A compact query should make ended/current distinctions
explicit without requiring prose parsing.

There is a sibling, `IATg_OV4a`, for the narrower batch-ID/refusal behavior and
a child, `L9DY_o3wE`, for byte-exact spec output. Refinement should avoid
duplicating those scopes while giving them a coherent query/output contract.

## Question

What is the smallest stable read surface that supports both human browsing and
low-token orchestration without turning every consumer into a parser for
`show`'s prose?

The leading design is a `list`/`query` verb with composable filters
(`--state`, `--parent`, `--band`, `--limit`/`--all`) and a compact default row,
plus a shared structured form such as `--json`. `show ID` could use the same
schema for a single record. A field projection (`--field state --field title`)
would be useful for shell callers, but should not invent a second incompatible
schema.

Any design should answer these measured cases in one call:

1. All pullable todo items in priority order.
2. All items under a parent, including completed children.
3. Six known IDs projected to ID/title/state/resolution.
4. One item's raw spec for `spec --base`.
5. Text search restricted to open work.

## Constraints

- Preserve the concise human-oriented default `show` output.
- Reuse the board's existing derived priority and FTS index.
- Bound output by default; require an explicit `--all` or limit override.
- Define one stable structured schema shared by list/find/show rather than
  separate ad-hoc JSON shapes.
- Keep `IATg_OV4a` and `L9DY_o3wE` as children or absorbed implementation
  slices, not parallel duplicate fixes.

## Non-goals

This container does not choose the final verb name or commit to JSON over
another structured encoding. It is not a performance item: the observed cost
is oversized and repeated output, not slow SQLite queries.
