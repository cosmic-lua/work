## Change

Four live definitions of what a spec must contain disagreed with each
other. The gate is one section:

```
$ grep -n 'READY_SECTIONS' _work/spec.tl
27:local READY_SECTIONS < const >: {string} = {
106:local function ready_gaps(body: string): {string}
```

`_work/doctrine_bar.tl` agrees ("A pullable spec carries one section —
`## Change`") and states that neither Goal nor Enablement exists. But
`_work/brieftext.tl`'s RESEARCH template taught a five-section bar
including `## Goal` and `## Acceptance`, while its REFINE template, in
the same file, forbade `## Acceptance`.

Measured consequence across the 1342 live spec sidecars: 482 carry
`## Goal`, 428 `## Acceptance`, 303 `## Enablement` — and in the most
recent chronological decile those still sit at 29%, 9% and 0%, so a
template was still minting sections no reader honors.

Make every template teach the bar the gate enforces:

1. `_work/brieftext.tl`, RESEARCH step 3: replace the five-section list
   with `## Change`, plus `## Non-goals` where a wall is at stake and
   `## Access` where the spec's own text reaches a repository other
   than the item's own. Keep the measured-evidence requirement as prose
   rather than as a list entry. Add the explicit prohibition — no
   `## Goal`, no `## Acceptance` — because 482 and 428 legacy items are
   what an agent pattern-matches from, so silence does not stop it.
2. `_work/brieftext.tl`, RESEARCH step 4: re-anchor "the summary table
   the spec's `## Acceptance` names" to `## Change`.
3. `_work/brieftext.tl`, REFINE: name `## Access` alongside
   `## Non-goals`, and forbid `## Goal` beside the existing
   `## Acceptance` prohibition.
4. New file `_work/brieftext_bar_test.tl`: pin the bar sentence and both
   prohibitions in RESEARCH and REFINE, assert no template names
   `## Goal` or `## Enablement`, and pin BUILDER's surviving
   legacy-Acceptance read so it cannot be flipped into a requirement.
   A new file rather than growth in `_work/brieftext_test.tl`, which the
   added cases would leave three lines under the 500-line cap, and
   which the repo already splits by topic (`brief_out_test.tl`,
   `brief_rework_test.tl`, `brief_session_test.tl`).

`_work/doctrine_bar.tl`, `_work/doctrine.tl` and
`_work/brieftext_review.tl` need no change: none instructs an author to
write a retired section.

## Non-goals

`_work/spec.tl`'s `READY_SECTIONS` and every other code path — this is
prose inside Teal string constants plus the test expectations that move
with it.

`## Evidence`. Its move out of the spec is settled by D47 in
cosmic-lua/cosmic but depends on a mechanism that does not exist yet, so
templates keep teaching it and nothing about its handling changes.

The `## Access` convention itself, which `_work/gitowner.tl` and
`_work/gitready.tl` machine-read.

Dropping `## Acceptance` from the fixtures in `_work/action_test.tl`,
`action_ci_test.tl`, `action_queue_test.tl`, `converge_test.tl` and
`intake_test.tl`: they exercise the reader against legacy-shaped
sidecars, and changing them weakens that coverage.

## Access

cosmic-lua/cosmic, read — the decision record this implements
(https://github.com/cosmic-lua/cosmic/pull/1842) and its `docs/decisions/`
numbering; no cosmic-side file changes.
