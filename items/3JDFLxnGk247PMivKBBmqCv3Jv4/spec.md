## Evidence

`7rqT_Yu31`'s fresh-context review (PR #127, commit `b01f519e15f8a5b7fe7d49e56470b379b2b9e251`)
accepted the change but named two concrete, non-blocking gaps against the
new `_work/fixture.tl` retry logic and its test:

1. `_work/fixture.tl:48-56` (the comment above `git()`) embeds forensic
   detail — specific PR numbers (#124/#125), CI run/job IDs, and
   timestamps — directly in a permanent source comment. `grep -rn "PR #[0-9]"
   _work/*.tl` (excluding `*_test.tl`) turns up only this one site: it is
   the only place in the non-test tree that cites a PR number this way.
   That evidence trail already lives in the board item's own `## Evidence`
   section; the source comment would read better stating just the
   mechanism and rationale (what the retry guards against and why), since
   the specific run IDs will read as stale trivia once the flake is a
   distant memory.
2. `_work/fixture_test.tl`'s three landed cases cover: the retry
   recovering within budget, an unrelated `worktree add` failure still
   failing immediately, and a non-`worktree-add` subcommand never being
   retried — but no case exercises the "give up and fail loudly" path
   when the locked-race text persists past `WORKTREE_ADD_RETRIES`
   attempts (i.e., every attempt returns the locked-file stderr). The
   original spec's own wording only required proving the retry recovers,
   so this isn't a spec violation — but it is a real coverage gap in the
   one piece of logic most likely to need touching again if the retry
   budget or matching pattern ever changes.

## Change

In `_work/fixture.tl`, trim the comment above `git()`'s retry logic to
state the mechanism and rationale only (what failure it retries and why,
without the specific PR numbers, CI run/job IDs, or timestamps — those
stay in the board item's history, not the source).

In `_work/fixture_test.tl`, add one more case: stub `child.run` to return
the locked-file failure text on every attempt (exhausting
`WORKTREE_ADD_RETRIES`), and assert the retry loop gives up and surfaces
the original loud failure exactly as before this feature existed (same
error text, no swallowed failure, no infinite retry).

## Non-goals

Not changing the retry count, the matching pattern, or any other
behavior of the retry logic itself — this is a comment trim plus one
added test case, not a redesign. Not touching any other file.

## Access

cosmic-lua/work, read and write on a branch; no other repository.
