`_work/brief.tl`'s `cmd_brief` assigns `facts.bounce_context` only inside
the `if kind == "builder" then` branch (around lines 391-406). For
`kind == "research"` the field is never touched, so it stays `nil`,
`briefcontext.need` reads it as ABSENT, and every research brief renders
the literal `<BOUNCE_CONTEXT>` token and names it as a survivor on the
verdict line.

This is not the fresh-pull case «S4pF_DMGT» fixed. It holds for a GENUINE
research rework — an item carrying a `request changes` verdict on its
research result, which does have a bounce paragraph to splice. The
rework hand-back a research builder is supposed to read is therefore never
spliced at all, for any research item, in any state.

Verified empirically during «S4pF_DMGT»'s review, before and after that
diff (so it is pre-existing and unchanged by it): a research item put into
`request changes` via `research_handover` plus a seeded verdict rendered a
verdict line reading `fill <REPO>, <WORKTREE>, <BOUNCE_CONTEXT>`.

Assign `facts.bounce_context` for the research kind the same way the
builder kind now does — unconditionally, so `""` reads as INTENTIONALLY
EMPTY — resolving the actual bounce paragraph when the item carries a
`request changes` verdict on its research result.

Add a regression asserting both halves, since the fresh case alone would
pass on a fix that still never splices: a research item with no bounce
renders no literal `<BOUNCE_CONTEXT>` and does not name it as a survivor;
a research item in `request changes` renders its actual bounce paragraph.
`_work/brief_test.tl`'s existing `research_handover` and
`fixture.raw_seed_item` helpers are what the probe used, and
`brief_and_capture` is the capture pattern.
