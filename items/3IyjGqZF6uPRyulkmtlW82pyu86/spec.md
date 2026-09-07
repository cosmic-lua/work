## Evidence

`cat bin/gitboard.pin` on cosmic main → `2026-09-06-32ec450` (work main at #69). Work main is now `ce28c12` (`git -C /home/user/work log --oneline -1 origin/main`), one merge past the pin: #70 — `verdict accept` records the verdict before attempting to land, so a refused landing (the proxy's pinned GraphQL set, HTTP 403) rides the verdict line instead of dropping the judgment; every reviewer this pass had to be told to pass `--no-land` to avoid that loss. The release for that head is published: `curl -sSL -o /dev/null -w '%{http_code}' https://github.com/cosmic-lua/work/releases/download/2026-09-07-ce28c12/SHA256SUMS` → 200; its `gitboard` line is `200563ae813db0dd5c2fd76861c176e6fbb38b90a99b0f4cbc6015b56181fe00`, equal to `sha256sum` of the downloaded asset.

## Change

`bin/gitboard.pin`: `url` → `https://github.com/cosmic-lua/work/releases/download/2026-09-07-ce28c12/gitboard`, `sha256` → `200563ae813db0dd5c2fd76861c176e6fbb38b90a99b0f4cbc6015b56181fe00`, both lines together, nothing else. Verify with `bin/gitboard help verdict` from the checkout: the pinned binary downloads, verifies, and runs; paste the verdict line in the PR body.

## Non-goals

No change to `bin/gitboard` itself, no other pin.

## Access

cosmic-lua/work, read only: the release asset download the pin names.

## Ready when

`bin/gitboard.pin` names `2026-09-07-ce28c12` and its sha, and `bin/gitboard help verdict` from a clean checkout prints the usage from that release.
