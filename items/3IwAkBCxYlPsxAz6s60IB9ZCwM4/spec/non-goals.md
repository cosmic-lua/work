- Not changing `bounce_context()` itself, or `gh.reviews`/
  `gh.latest_request_changes` — the lookup is correct for what a
  formal GitHub review actually is; the mismatch is on the
  instruction side.
- Not changing the `accept` or `reject` verdict instructions, which
  don't rely on `bounce_context` the same way.
- Not touching how `gitboard verdict` itself records board state —
  this item is only about what the review AGENT posts to GitHub.
