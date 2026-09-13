Not `review`-kind briefs — `brieftext_review.tl` already mints a
per-round session label and reads CI state fresh each time
(`ci_refusal`); this item is builder-kind only. Not the separate,
already-filed `rNh1_b1Se` candidates (headroom/per-file-check/bounce-
diff/base-conflict sentences) — that item is resolved (PR #1697,
merged) and covers other `brief.tl` gaps, explicitly not this one.
Not changing how a review's verdict is recorded or what `gitboard
verdict` accepts — this only reads what already exists on GitHub, not
what the board itself stores. Not a review-comment READ for anything
other than filling `<BOUNCE_CONTEXT>` — no new write path, no new
`gh.tl` mutation (the board's GitHub access stays read-only, per
`_work/api.tl`'s own stated design).
