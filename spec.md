## Evidence

`gitboard brief builder cOu8_PnMv`'s verdict line asked the
orchestrator to fill `<N>`, and `brief builder RxN2_253n`'s asked for
`<REVIEW_SESSION>`; neither is a placeholder of the builder template.
Both strings sit inside the items' own specs (a `take ID --pr <N>`
example; the label placeholder the review brief used to carry), which
the brief quotes verbatim. `_work/brief.tl` finds survivors by
scanning the whole filled text for the `<UPPER_SNAKE>` shape, so any
spec that quotes such a token — every board-tooling item does — makes
the verdict line lie, and an orchestrator following it looks for a
placeholder that is not there (the 2026-09-04 routine log records the
detour on two of six briefs).

**Reconfirmed 2026-09-07, a second session.** Board item `Bfzm_Iqlc`'s
own spec (Evidence section) quotes `new --parent <ID>` as literal
command syntax. Both `brief builder Bfzm_Iqlc` and `brief review
Bfzm_Iqlc`'s verdict lines flagged `<ID>` as needing to be filled —
`gitboard-brief: ... fill <ID>, then read it whole` — even though the
rendered brief body was already complete; the `<ID>` sits entirely
inside the quoted spec prose, never in the template's own unfilled
slots. Caught only because this orchestrator had already hit the exact
same false-positive shape once before in this same session and knew
to check the body for a literal, unfilled `<ID>` token before
believing the verdict line. An orchestrator without that prior
context would detour exactly as the 2026-09-04 log describes.

## Change

`_work/brief.tl`: the survivor list is the template's own placeholder
set — the names the template source declares (`<WORKTREE>`,
`<BOUNCE_CONTEXT>`, `<HEAD_SHA>`, `<REVIEW_SESSION>`, and whatever else
each kind's text carries) — checked for presence after filling, never
a regex over the filled body. A placeholder-shaped token inside the
quoted spec is spec text and is neither reported nor touched.

`_work/brief_test.tl`: a fixture spec containing `<N>` and
`<REVIEW_SESSION>` in its body yields a verdict line naming only the
template's unfilled placeholders; a fully filled brief names none.

## Non-goals

No change to what the placeholders are or who fills them.
