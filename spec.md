## Current refinement — native Cosmic reuse review

This refinement supersedes conflicting implementation assumptions in the historical spec below; its original evidence is retained for context.

The hypothesized capture-order defect below is unconfirmed and is not apparent in current work a43d1824cd5d48408b780f2ac16a3b42e0c5cd38: `fill(template, values)` writes a separate body, and `survivors(template, values)` still receives the original template. First reproduce with the exact current tool and spec. If it no longer reproduces, retain useful regression coverage and record that result rather than forcing a code change based on the old hypothesis. Test inserted `<ID>`, `<BOUNCE_CONTEXT>`, and `{{.field}}` as literal data across builder/review variants. Carry these cases into work#103 and Cosmic#1809; generic template parsing belongs in Cosmic, board-specific unresolved-value policy remains in GitBoard.

## Evidence

`«WyFa_GL3c»` (merged, PR #88) fixed `_work/brief.tl`'s `survivors()`
to report a placeholder only when it is BOTH declared by the raw
template source AND unfilled in `values` — specifically to stop a
spec-quoted example token (e.g. `<N>`, `<ID>`) from being
misidentified as a real gap. That fix holds for tokens the spec quotes
directly in a section rendered by simple string substitution. It does
NOT hold for tokens quoted inside the item's OWN spec text once that
spec text is itself spliced into the brief body (every kind's `<SPEC>`/
`<CURRENT_SPEC>` slot) — a second, distinct path by which
placeholder-shaped text can end up in the rendered output.

Reproduced live, 2026-09-07, filing `«VFYg_q5kz»` (a real board item,
`cosmic-lua/cosmic`'s stale `bin/gitboard.pin`): its own Evidence
section quotes, as ordinary prose describing a repro command, the
literal text `` `bin/gitboard brief builder <ID>` `` and
`` `<BOUNCE_CONTEXT>` ``. Neither `<ID>` nor `<BOUNCE_CONTEXT>` is a
placeholder the REVIEW template (`_work/brieftext_review.tl`) itself
declares anywhere outside the spliced spec section — confirmed by
reading the full rendered brief top to bottom; both tokens appear
EXACTLY ONCE, inside the quoted Evidence prose, nowhere else. Yet
`bin/gitboard brief review 3J0xpOPhxr7mqDDnq1hVFYgq5kz` (run under the
CURRENT pin, carrying WyFa_GL3c) reported:

    gitboard-brief: ... fill <ID>, <BOUNCE_CONTEXT>, then read it whole ...

This is the exact false-positive shape WyFa_GL3c was written to
eliminate, reappearing through a second injection path the fix's own
test coverage apparently didn't exercise (its fixture, per the merged
PR's own description, quoted placeholder tokens directly in the
BUILDER template's rendering, not inside a spec body that gets
spliced into the `<SPEC>` slot before survivor-scanning runs).

Likely root cause (unconfirmed — read the actual call order before
assuming): if `unfilled(template)`/`survivors(template, values)` is
called with the TEMPLATE STRING AFTER the item's spec has already been
substituted into its `<SPEC>`/`<CURRENT_SPEC>` slot (rather than the
pristine, pre-substitution template source), then any
`<UPPER_SNAKE>`-shaped substring the spec's own prose happens to
contain reads as a "declared placeholder" of the template — the exact
bug class WyFa_GL3c fixed, just reached through a different order of
operations. Confirm by reading `_work/brief.tl`'s fill/render pipeline
directly: does spec-splicing happen before or after the point
`unfilled()` captures its "raw template" argument?

## Change

Fix `_work/brief.tl` so `unfilled()`'s "raw template" argument is
always captured BEFORE any spec content (or any other externally
supplied prose — review findings via `ROUND_CONTEXT`, rework notes via
`BOUNCE_CONTEXT`, etc.) is spliced into the body — the declared-name
extraction must run against the template as authored, never against
a body that already carries user/spec-controlled text. If the
resolution is different once the actual code is read (e.g. spec
splicing already happens correctly before the scan, and the real bug
is elsewhere), say so in the PR body with the actual root cause found.

Add a regression test: a fixture spec whose body quotes a
placeholder-shaped token (e.g. `<ID>`) in ordinary prose, rendered via
EACH kind that splices a spec into the body (builder and review at
minimum), asserting the verdict line names no survivor from the
spec's own quoted text — mirroring the existing test WyFa_GL3c added
for direct-render false positives, but exercising the spec-splice path
specifically, since that is the gap this item closes.

## Non-goals

Not re-litigating `survivors()`'s core design (declared-name-vs-value-nil
matching) — that mechanism is sound; this item fixes what string it is
handed. Not touching the already-filed, unrelated `BOUNCE_CONTEXT`
unset-on-fresh-pull bug (`«S4pF_DMGT»`) — that is a values-population
bug on the builder path specifically; this item is a template-string
capture-order bug affecting every kind that splices a spec.

## Access

cosmic-lua/work, read and write on a branch; no other repository.

