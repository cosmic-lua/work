A composing verb that is never published leaves the clone-local snapshot slot
occupied. Every later composing verb then refuses with:

    gitboard-<verb>: snapshot composition belongs to <session>; pass the same
    --session or set GITBOARD_SESSION

That message names the owning session and nothing else: not what the pending
snapshot would do, not how to look, not how to discard it. A caller who does
not remember composing anything has to discover `gitboard snapshot --check`,
then find the commit, then read it, before it can decide whether to publish or
abandon.

Make the refusal carry the pending snapshot's identity and its one-line
summary — the same summary `snapshot` already renders — plus the two exits:

    gitboard-done: REFUSED: a snapshot is already composed by <session>:
      <sha> "new 3JOpng1c --a title starting with dashes"
      publish it (gitboard publish <sha>) or discard it
      (gitboard snapshot --abandon <sha>)

Where the owning session is the caller's own, the existing "pass the same
--session" advice still applies and should still be shown.

Regression: compose a snapshot under one session, invoke a composing verb
under another, and assert the refusal names the snapshot's sha and summary and
both exits.
