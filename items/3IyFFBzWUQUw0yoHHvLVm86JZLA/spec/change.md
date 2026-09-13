`bin/gitboard.pin`: `url` → `https://github.com/cosmic-lua/work/releases/download/2026-09-06-dee6b8c/gitboard`,
`sha256` → the `gitboard` line of that release's `SHA256SUMS`
(`72f8b8926eea0fdea73c43e37dcee625ebb3df1d985b5ff7573790f933e7bf4e`), both lines together, nothing else. Verify with
`bin/gitboard verdict --help` from the checkout: the pinned binary
downloads, verifies, and its usage lists `--body` and `--no-land`;
paste that in the PR body.
