Extend the owner-mismatch refusal in _work/snapshot_workspace.tl compose()
to identify the pending snapshot by its full commit SHA and a clearly quoted
or labeled one-line subject from that commit's existing identity.message.
Use the pending commit's message, not the summary of the refused operation.
The current snapshot CLI prints the SHA and publication report rather than
this subject; no new Git read or summary API is needed.

Preserve the existing owner name and "pass the same --session or set
GITBOARD_SESSION" remedy. Add concrete inspect, publish and abandon commands:
gitboard snapshot, gitboard publish FULL_SHA, and gitboard snapshot --abandon
FULL_SHA. The commands use the validated pending SHA only, never summary
text as an argument. Preserve the caller's existing verdict prefix/status.

Render only the first physical message line. Escape ASCII control bytes
0 through 31 and 127, including CR, TAB and ESC, so the displayed subject
cannot add lines or terminal controls. Do not print commit body or logical
author trailers. Keep the diagnostic data readable even when the subject
contains quotes, backslashes or a dash-leading title.

Extend _work/snapshot_feedback_test.tl's existing cross-session composing
refusal test. Assert pending full SHA and subject, owner and session remedy,
and the three valid commands. Assert refusal leaves the snapshot ref,
canonical head and publication recovery state unchanged. Add a case with a
multiline message and control characters to prove a one-line escaped subject
and no body/trailer leak. Retain the existing frozen-summary checks.
