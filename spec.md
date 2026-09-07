## Evidence

cosmic-lua/work published release `2026-09-07-63bcb7a` (built from 63bcb7abf7f6593e807d8b6e2cce6e711a37cb0b) carrying work#76 — `take --open`/`--pr N` seed a `running` ci_checks row at handover, closing the pre-sync stall — and work#77 — the own-PR bounce marker predicate is shared between `gh.tl` and `brief.tl`'s round counter via a new `_work/bounce.tl`. `bin/gitboard.pin` names `2026-09-07-ee58808`. The asset's sha256, measured on the downloaded binary: `4beafac3c0172098a00b94379dacce785c2b47dceefae96ff88844c609554f72`.

## Change

`bin/gitboard.pin` names `https://github.com/cosmic-lua/work/releases/download/2026-09-07-63bcb7a/gitboard` with that sha256. Two lines; nothing else.

## Non-goals

No change to `bin/gitboard`; no cosmic pin change.

## Access

cosmic-lua/cosmic, read and write on a branch; cosmic-lua/work, read only (the release asset the pin names, downloaded once to measure its sha256).

## Ready when

`bin/gitboard help verdict` runs from the new pin (the sha verifies) and, right after `take ID --open`, `gitboard show ID` prints a `ci: running` line.
