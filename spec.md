## Evidence

`cat bin/gitboard.pin` on cosmic main 5fc1aa4 → `2026-09-06-edeebf5` (work main at #67). Work main is now `32ec4500` (`git -C /home/user/work log --oneline -1 origin/main`), two merges past the pin: #68 (bar: the sweep pattern and its `--find` count, unconditional; `REVIEW` step 2 re-runs it) and #69 (`brief review` fills `<ROUND_CONTEXT>` with round 1's findings on a moved head). Until the pin moves, every second-round review brief is hand-assembled by the orchestrator (measured this pass: 25–40% of a round's calls saved when it is). The release for that head is published: `curl -sSL -o /dev/null -w '%{http_code}' https://github.com/cosmic-lua/work/releases/download/2026-09-06-32ec450/SHA256SUMS` → 200; its `gitboard` line is `6913469e5d8cf5a4ae9ddede025e8a0b795234f1d64cd285a3a53ef8112dd84c`, equal to `sha256sum` of the downloaded asset.

## Change

`bin/gitboard.pin`: `url` → `https://github.com/cosmic-lua/work/releases/download/2026-09-06-32ec450/gitboard`, `sha256` → `6913469e5d8cf5a4ae9ddede025e8a0b795234f1d64cd285a3a53ef8112dd84c`, both lines together, nothing else. Verify with `bin/gitboard help brief` from the checkout: the pinned binary downloads, verifies, and runs; paste the verdict line in the PR body.

## Non-goals

No change to `bin/gitboard` itself, no other pin.

## Access

cosmic-lua/work, read only: the release asset download the pin names.

## Ready when

`bin/gitboard.pin` names `2026-09-06-32ec450` and its sha, and `bin/gitboard help brief` from a clean checkout prints the brief usage from that release.
