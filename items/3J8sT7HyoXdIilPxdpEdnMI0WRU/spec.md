## Evidence

Across the `xL2i_AJuE` and `1PxG_xw8c` build/review rounds on 2026-09-10, fresh agents followed the product checkout's `bin/gitboard`/board-wrapper path. The wrapper had no cached binary, attempted a network bootstrap, and retried blocked DNS before failing. The orchestrator already had a verified working command, `sh <board-root>/o/bin/gitboard`, but that command and its cwd were not present in the delegated brief. The same correction had to be sent manually to multiple fresh reviewers.

This is distinct from completed `5VQX_QrYT`: its verified runtime prepares product worktrees; it does not make a fresh agent's board-control invocation explicit and executable.

## Change

Make generated builder, rework, and review briefs carry the exact caller-supplied GitBoard invocation and cwd when those values are provided. Render one copy-pasteable command prefix for every board read or mutation in the brief. The command must preserve an explicit loader such as `sh` and an absolute executable path; do not reduce it to a guessed product-local `bin/gitboard`.

When no caller command is supplied, label the fallback as unresolved rather than directing an agent to bootstrap a board binary from the product checkout. Add an end-to-end fixture for an APE invoked through `sh`, an absolute board executable outside the product worktree, and a board cwd outside that worktree. Assert the rendered brief contains the exact invocation/cwd and no product-local bootstrap instruction.

## Acceptance

A fresh delegated agent can run every board command in the generated brief without network access or path discovery. Tests fail if the loader, absolute executable, or cwd is dropped, or if `bin/gitboard` is silently substituted.

## Non-goals

No new runtime downloader, credential discovery, shell evaluation, or change to product bootstrap.

## Access

`cosmic-lua/work`, read and write on a branch. Tests use isolated local fixtures and no network.
