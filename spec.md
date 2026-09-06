## Evidence

`cat bin/gitboard.pin` in cosmic-lua/cosmic main →
`url = https://github.com/cosmic-lua/work/releases/download/2026-09-06-1ff3238/gitboard`.
cosmic-lua/work main is now `76b510bf` (`git log --oneline -1 origin/main`),
seven merges past that pin: #48 (`show --todo N`), #55 (`brief`'s
`product_root()` cwd fallback), #56 (`spec` identical body says so), #57
(`show` prints a doing row's reviewer), #58 (`gitboard worktree ID`), #59
(re-pushed diff's stale CI row no longer deadlocks the pull). None is live
for any session until the pin moves: this pass's PR 1759 reviewer still
hit the `cd /home` product-root defect #55 fixes (one failed call), and
every builder worktree is still made by hand instead of `worktree ID`.

Every push to work's main publishes a release tagged
`YYYY-MM-DD-<7-char sha>` with a `SHA256SUMS` asset beside `gitboard`.

Ready when: `curl -sSL -o /dev/null -w '%{http_code}' https://github.com/cosmic-lua/work/releases/download/2026-09-06-76b510b/SHA256SUMS` prints `200`.

## Change

`bin/gitboard.pin` in cosmic-lua/cosmic: set `url` to
`https://github.com/cosmic-lua/work/releases/download/2026-09-06-76b510b/gitboard`
and `sha256` to the `gitboard` line of that release's `SHA256SUMS`
(`curl -sSL <release>/SHA256SUMS`), pasted verbatim. Both lines
together, nothing else in the diff. Verify by running
`bin/gitboard help worktree` from the checkout — the pinned binary
downloads, its sha verifies, and the verb's help prints; paste that
first line in the PR body.

## Non-goals

No change to `bin/gitboard` (the trust-root script), no other pin, no
docs.

## Access

cosmic-lua/work, read only: the release asset download
(`releases/download/2026-09-06-76b510b/{gitboard,SHA256SUMS}`) the
pin names, and nothing else.
