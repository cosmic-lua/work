`_work/brief.tl`: the survivor list is the template's own placeholder
set — the names the template source declares (`<WORKTREE>`,
`<BOUNCE_CONTEXT>`, `<HEAD_SHA>`, `<REVIEW_SESSION>`, and whatever else
each kind's text carries) — checked for presence after filling, never
a regex over the filled body. A placeholder-shaped token inside the
quoted spec is spec text and is neither reported nor touched.

`_work/brief_test.tl`: a fixture spec containing `<N>` and
`<REVIEW_SESSION>` in its body yields a verdict line naming only the
template's unfilled placeholders; a fully filled brief names none.
