`bin/gitboard.pin` in cosmic-lua/cosmic: set `url` to
`https://github.com/cosmic-lua/work/releases/download/2026-09-06-76b510b/gitboard`
and `sha256` to the `gitboard` line of that release's `SHA256SUMS`
(`curl -sSL <release>/SHA256SUMS`), pasted verbatim. Both lines
together, nothing else in the diff. Verify by running
`bin/gitboard help worktree` from the checkout — the pinned binary
downloads, its sha verifies, and the verb's help prints; paste that
first line in the PR body.
