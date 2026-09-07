## Evidence

`bin/cosmic.pin` on cosmic main → `2026-09-06-b5a9003` (2026-09-06 13:24Z). Release `2026-09-07-2b2002d` was cut by workflow_dispatch from main 2b2002d (run 34072146493, success at 01:14Z) and carries everything this pass landed that the pinned release cannot yet run in generation 1: `--make coverage --min PCT [--min-file PCT]` (#1778 — CI's ci lane refused the flag under the old pin, so pr.yml's floor is staged behind this bump, «COZq_Kk4X»), `--check lint --max-lines N` (#1775), `_cli/lint_limit`/`_make/coverage_limit`, the cosmic.ast chain through `--rewrite --apply` (#1766, #1777), and the AST-keyed cast inventory and doc signatures (#1770, #1774). The asset downloads (HTTP 200, 9356562 bytes); its sha256 is `b4bb8bde84fc54c4298e4d63d949a1af071d2ff5a2e1ba095fa70d9e342ee434`.

## Change

`bin/cosmic.pin`: `url` → `https://github.com/cosmic-lua/cosmic/releases/download/2026-09-07-2b2002d/cosmic-lua`, `sha256` → `b4bb8bde84fc54c4298e4d63d949a1af071d2ff5a2e1ba095fa70d9e342ee434`, both lines together, nothing else. Verify with `bin/cosmic --version` (or `--help`) from a checkout with no `o/bin/cosmic`: the trust root downloads, verifies, and execs the new release; then `bin/cosmic --make ci` converges from it. `_build/coldbuild_test.tl` runs generation 1's check under this pin.

## Non-goals

No change to `bin/cosmic`; no pr.yml change (that is «COZq_Kk4X», on top of this).

## Access

cosmic-lua/cosmic, read only: the release asset download the pin names.

## Ready when

`bin/cosmic.pin` names `2026-09-07-2b2002d` and its sha, and CI's four lanes are green on it.
