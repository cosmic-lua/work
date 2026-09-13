The minted session label carries the orchestrator: `<kind>-<handle>-
<orch8>`, where `<kind>` is `build`, `research`, `review`, `refine` or
`decompose` and `<orch8>` is the first 8 characters of the session id
the tool already derives (`gitboard show`'s "session: ... (from
CLAUDE_CODE_SESSION_ID)" line). `gitboard brief KIND ID` fills the
label itself — the `<REVIEW_SESSION>` placeholder goes away — and
prints it on its verdict line so the orchestrator claims under the
same string (`take ID --session <label>`). `gitboard take` on a review
(and a pull) refuses a claim whose live holder is a different label:
`REFUSED: <id> is under review by review-<handle>-<other> — take over
a live review with --force --why`; today the identical label reads as
the same session re-taking and both proceed. `help orchestrate` and
`help review` state the label shape.

`_work/brief_test.tl`: the label appears filled, with the session's
own 8 characters. `_work/gittake_test.tl`: two labels differing only
in `<orch8>` on one item — the second `take` is refused at claim time.
A self-named reviewer (solo session) keeps `review-<handle>-<unique>`
as before; the shape is what changes.
