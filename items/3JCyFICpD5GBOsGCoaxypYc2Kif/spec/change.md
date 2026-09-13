Give a reviewer a way to review-claim an item without silently
recapturing an unrelated base:

- When `claim` targets an item already carrying a recorded `handover`
  (state `review`) and the caller's local repo's current base is NOT an
  ancestor of that handover, refuse the claim with a message naming
  both commits and pointing at `worktree ID --review` (which already
  starts at the exact handed-over commit) as the way to get a
  consistent local checkout — rather than silently recording a base
  that will only fail much later, at `verdict`.
- Separately, when the caller's local repo IS already positioned such
  that the handover is a descendant of the proposed base (e.g. because
  the caller fetched/checked out at or before the handover), `claim`
  should succeed as it does today.
