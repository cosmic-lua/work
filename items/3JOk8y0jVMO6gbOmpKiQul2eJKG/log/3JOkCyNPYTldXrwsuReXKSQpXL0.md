Measured 2026-09-16 while building «AAt2_Citw».

That item's spec instructed: "extend `_work/stateclaim_authority_test.tl` with
a case holding one active and two expired claims, asserting the output carries
the active claim's `current-claim` line, no line for either expired one, and
`expired-claims=2`."

That file cannot host the case. It imports `require("_work.stateclaim_authority")`
and exercises `authority.current`/`authority.historical` — receipt validation,
stale snapshots, reacquisition, first-parent merge history. It never imports
`_work/stateclaim`, whose `authority` function is what «AAt2_Citw» changes.

The spec's author read the module name and matched it to the function name.
The builder caught it with a single `Read` of the file's header and placed the
case in `_work/stateclaim_test.tl` instead, beside the source it tests, per
this repo's `*_test.tl`-beside-source convention — reporting the deviation
rather than following the spec literally.

Cost this time: one tool call, because the brief happened to frame the
placement as an open question rather than repeating the spec's instruction.
Had it not, the likely outcome is the case landing in the wrong file with an
unrelated import added to it, and a reviewer catching it a cycle later, or not
catching it at all.

Line counts at the time, none of them forcing the placement:
`_work/stateclaim.tl` 194, `_work/stateclaim_test.tl` 98,
`_work/stateclaim_authority_test.tl` 73, against a 500-line cap.