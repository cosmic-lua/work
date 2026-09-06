## Evidence

`cat bin/gitboard.pin` on cosmic main c5e2bf8 → `2026-09-06-dee6b8c` (work main at PR #66). Work main is now `edeebf53` (`git -C /home/user/work log --oneline -1 origin/main`), one merge past the pin: #67, `REVIEW_SCRIPT` — `brief review` picks a checkout-free script-shaped template for a mechanical diff (no `.tl` outside tests, or under 20 changed lines). Until the pin moves, every mechanical PR's review brief is the full fresh-worktree shape (36–48 calls measured this pass) and the orchestrator hand-writes the script shape (5–11 calls) every time. The release for that head is published: `curl -sSL -o /dev/null -w '%{http_code}' https://github.com/cosmic-lua/work/releases/download/2026-09-06-edeebf5/SHA256SUMS` → 200; its `gitboard` line is `fa9d16149e3b9f18c3b4629ec4c3feb23fb781641b00b4a6c873f0b2f5620594`, matching `sha256sum` of the downloaded asset.

## Change

`bin/gitboard.pin`: `url` → `https://github.com/cosmic-lua/work/releases/download/2026-09-06-edeebf5/gitboard`, `sha256` → `fa9d16149e3b9f18c3b4629ec4c3feb23fb781641b00b4a6c873f0b2f5620594`, both lines together, nothing else. Verify with `bin/gitboard help brief` from the checkout: the pinned binary downloads, verifies, and runs; paste the verdict line in the PR body.

## Non-goals

No change to `bin/gitboard` itself, no other pin.

## Access

cosmic-lua/work, read only: the release asset download the pin names.

## Ready when

`bin/gitboard.pin` names `2026-09-06-edeebf5` and its sha, and `bin/gitboard help brief` from a clean checkout prints the brief usage from that release.
