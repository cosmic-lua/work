Cover the read-failure branch with a case that omits the read reply and
asserts the reported error and that no write was sent.

Correct the `Landing` record's doc paragraph so it describes what
`attempted` actually distinguishes — a write sent or not — and names the
paths that answer a landing from a read alone.

Give the closed-unmerged result a `note` suffix that does not tell the
caller to land by hand, the way `already_merged` already does. Add a case
pinning the rendered suffix, since the existing closed-unmerged case
asserts the landing result rather than the sentence.
