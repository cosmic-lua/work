## Evidence

`_work/gitready.tl:143-144` enforces a spec-bar rule not documented in the
`bar` help topic: a spec whose `repo` reaches a repository the item's own
spec text doesn't declare fails with

    "spec reaches %s with no declared read access — name it under "
    .. "\"## Access\"; undeclared, it strands the claim now and the "
    .. "review just as surely"

`_work/gitowner.tl`, `_work/gitgraph.tl:43`, and `_work/spec.tl:5,114` all
implement and rely on the `## Access` section this rule enforces. But
`_work/doctrine.tl`'s `bar` topic body (lines 117-166) documents only
`## Change`, `## Acceptance`, `## Non-goals`, and "Ready when:" prose — no
mention of `## Access` at all. `gitboard help bar` is the only doctrine
surface a session consults before writing a spec, so a first-time filer
has no printed text pointing at a rule the tool already gates on.

Observed directly this session (`zpQB_k73O`, the 2026-09-04 `/work 9
--routine` friction log): a newly filed item was refused at `show` time
for missing `## Access`, resolved only by grepping other items' specs for
the convention (`git grep -l "## Access" ...`) rather than being told the
shape by `help bar` — 3 exploratory calls to close a bar `help bar`'s own
text gave no hint of.

## Change

In `_work/doctrine.tl`, add a paragraph to the `bar` topic's `body` (after
the existing `## Non-goals`/"Ready when:" material, before its closing
`]]`) documenting the `## Access` section: what triggers it (a spec's
`repo` differs from — or its prose reaches into — a repository beyond the
item's own), its required shape (one repository per line or clause under
the heading), and the exact refusal a missing one produces (quote
`_work/gitready.tl:143-144`'s message so a reader can recognize it).

## Non-goals

Not changing `gitready.tl`'s enforcement or the `## Access` convention
itself — this is a doctrine-text-only fix.
