## Evidence

cosmic-lua/work published release `2026-09-07-81e0660` (built from 81e066088f2ede4ad61414eb6787f9809ea8cd0e) carrying work#71 — `verdict request-changes`/`reject` posts a marked COMMENT review on the token's own PR instead of the REQUEST_CHANGES GitHub refuses with a 422 — and work#72 — `gitboard worktree` refuses an item the caller has not claimed. `bin/gitboard.pin` still names `2026-09-07-ce28c12`, so every orchestrator on the current pin still loses each own-PR bounce to a 422 (twice this pass: the work#71 review itself) and can still cut a worktree for an unclaimed item. The asset's sha256, measured on the downloaded binary: `43654c0d58eee617780dc769fe4aee180ecd66ed1008971d3fffdb42e99b0b75`.

## Change

`bin/gitboard.pin` names `https://github.com/cosmic-lua/work/releases/download/2026-09-07-81e0660/gitboard` with that sha256. Two lines; nothing else.

## Non-goals

No change to `bin/gitboard`; no cosmic pin change.

## Access

cosmic-lua/cosmic, read and write on a branch; no other repository.

## Ready when

`bin/gitboard help verdict` runs from the new pin (the sha verifies) and `bin/gitboard worktree` on an unclaimed item is refused.
