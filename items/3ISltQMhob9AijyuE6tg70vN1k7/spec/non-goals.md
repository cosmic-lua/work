- Do NOT edit anything under `skills/work/**` on `main`, and do NOT
  open a PR against `main`. This slice is `board`-branch machinery
  only; `review.md` already sanctions the PR-less research handover.
  Its one now-stale clause — that the reviewer then runs `done ID`,
  where this change ends the item inside the accept — is filed as its
  own capture and is not this slice's to fix.
- Do NOT change `gate.land_refusal` (`_work/gitgate.tl` lines 274–290).
  A force-move into `land` with no PR stays refused; the fix is that
  an evidence accept never goes there.
- Do NOT change `spec.READY_SECTIONS`. `## Result` is read where it is
  needed and is NOT added to the ready bar — a code slice must not
  start owing one.
- Do NOT relax the `--claim` refusal on a handover to `check`, and do
  NOT change `gitverdict`'s builder-distance refusal (line ~142). The
  review distance binds evidence slices exactly as it binds diffs.
- Do NOT touch `items/**`. This is a machinery change; no board state
  moves in the diff.
- Do NOT rebase or force-push `board`.
