## Evidence

`_work/ghland.tl`'s `pull_of` extracts a pull request number from a
recorded URL with an unanchored digit match, so a trailing non-digit tail
is silently dropped. `«ugaS_0KMn»` pinned the behaviour rather than
changing it — `_work/ghland_test.tl:67` asserts `.../pull/7abc` parses as
`7` — deliberately, because the same looseness is what accepts the URLs
GitHub's own navigation hands a person to paste: `.../pull/7/files`,
`.../pull/7#issuecomment-1`.

Its reviewer named the residual hazard, and it is a live one: that number
selects which pull request a merge `PUT` is aimed at. `target_of`
reconciles the *repository* against the item's own `repo` and refuses a
mismatch — added by `4f48ed42` for exactly this class of mistake — but
nothing reconciles the *number*. So a malformed tail that should be a
refusal instead merges a real, different, unreviewed pull request in the
right repository.

The fix the reviewer proposed costs nothing the pin defends: anchor the
digits at a boundary — `/`, `#`, `?`, or end of string — which keeps every
real URL the existing test already enumerates and refuses `.../pull/7abc`.
The two goals are not actually in tension; the pin was written as though
the only alternative were a full anchor to end-of-string.

## Change

Anchor `pull_of`'s number at a boundary — the next character is `/`, `#`,
`?`, or nothing — so a URL whose number is followed by other characters is
refused rather than truncated. Keep every currently-accepted real URL
shape accepted.

Update the `.../pull/7abc` case to assert the refusal instead of `7`, and
say in the PR body that this reverses a behaviour `«ugaS_0KMn»` pinned on
purpose, with the reason. Keep the cases that pin `.../pull/7/files`,
`.../pull/7#issuecomment-1`, and the bare `.../pull/7`, and add one for a
`?`-suffixed URL if none exists.

## Non-goals

Not changing `target_of`, the host check, or anything else `pull_of`
refuses today — the non-GitHub-host and malformed-URL branches keep their
current answers. Not validating the number against the provider. Not
touching the landing's request sequence.

## Access

cosmic-lua/work, read and write on a branch; no other repository.
