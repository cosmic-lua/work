Anchor `pull_of`'s number at a boundary — the next character is `/`, `#`,
`?`, or nothing — so a URL whose number is followed by other characters is
refused rather than truncated. Keep every currently-accepted real URL
shape accepted.

Update the `.../pull/7abc` case to assert the refusal instead of `7`, and
say in the PR body that this reverses a behaviour `«ugaS_0KMn»` pinned on
purpose, with the reason. Keep the cases that pin `.../pull/7/files`,
`.../pull/7#issuecomment-1`, and the bare `.../pull/7`, and add one for a
`?`-suffixed URL if none exists.
