## Evidence

cosmic-lua/work published release `2026-09-07-ee58808` (built from ee58808e816281287dc2ed64bfec60cae7e6701e) carrying work#73 — `new --parent` ranks a child last and the verdict line says where — work#74 — `show` prints the cached `ci:` line for a doing item's PR — and work#75 — a `REQUEST_CHANGES` refused with a 422 is re-posted once as the marked `COMMENT`, so an app installation token's bounce records instead of failing (it failed twice this pass on the pin that carries only #71's own-login check). `bin/gitboard.pin` names `2026-09-07-81e0660`. The asset's sha256, measured on the downloaded binary: `41f6535508853376e833a485c2900edb09aca127e62b4ea7259b561a861f2b9d`.

## Change

`bin/gitboard.pin` names `https://github.com/cosmic-lua/work/releases/download/2026-09-07-ee58808/gitboard` with that sha256. Two lines; nothing else.

## Non-goals

No change to `bin/gitboard`; no cosmic pin change.

## Access

cosmic-lua/cosmic, read and write on a branch; cosmic-lua/work, read only (the release asset the pin names, downloaded once to measure its sha256).

## Ready when

`bin/gitboard help verdict` runs from the new pin (the sha verifies) and `bin/gitboard show <a doing item with a PR>` prints a `ci:` line.
