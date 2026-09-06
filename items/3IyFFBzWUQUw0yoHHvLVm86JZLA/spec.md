## Evidence

`cat bin/gitboard.pin` on cosmic main → `2026-09-06-76b510b` (work
main at PR #58). Work main is now `dee6b8cd` (`git log --oneline -1
origin/main`), four merges past the pin: #60 (bar doctrine: one
mechanism, grep hit), #61 (`take --open` — the board opens the PR),
#62 (`verdict` lands/bounces/closes the PR). Until the pin moves,
every builder still opens its PR through an MCP tool and every
reviewer still arms auto-merge through one — the two remaining
GitHub reaches in the briefs (`grep -c mcp__github
/tmp/…/scratchpad/rprompt_62.md` → 3 in the last review env note).
The release for that head is published:
`curl -sSL -o /dev/null -w '%{http_code}' https://github.com/cosmic-lua/work/releases/download/2026-09-06-dee6b8c/SHA256SUMS` → 200.

Ready when: `curl -sSL -o /dev/null -w '%{http_code}' https://github.com/cosmic-lua/work/releases/download/2026-09-06-dee6b8c/SHA256SUMS` prints `200`.

## Change

`bin/gitboard.pin`: `url` → `https://github.com/cosmic-lua/work/releases/download/2026-09-06-dee6b8c/gitboard`,
`sha256` → the `gitboard` line of that release's `SHA256SUMS`
(`72f8b8926eea0fdea73c43e37dcee625ebb3df1d985b5ff7573790f933e7bf4e`), both lines together, nothing else. Verify with
`bin/gitboard verdict --help` from the checkout: the pinned binary
downloads, verifies, and its usage lists `--body` and `--no-land`;
paste that in the PR body.

## Non-goals

No change to `bin/gitboard` itself, no other pin.

## Access

cosmic-lua/work, read only: the release asset download the pin names.
