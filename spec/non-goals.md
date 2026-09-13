- **The `block` deadlock race is NOT in scope.** The capture's item
  (3) — two sessions racing reciprocal `block X Y` / `block Y X`,
  landing a cycle because the check runs against the local checkout —
  needs the revalidate to re-ask a graph invariant, not a limit. It
  is a different fix and gets its own item; `status` already reports
  a cycle when one lands.
- **`store.publish`'s leftover commit is NOT in scope.** The
  capture's closing paragraph (a failed publish keeping the local
  commit, and a mid-`save` failure leaving a dirty index) is a
  `_work/store.tl` change, a different file and a different failure.
  Its own item.
- No change to `commit_and_publish`'s existing parameters or their
  order, and no sweep of call sites that do not need the new ones —
  an options-record refactor would touch every verb and is not what
  this fixes.
- No change to `flow.LIMITS`, to `flow.is_arrival`, or to
  `flow.admits_over_limit`.
- No change to any verdict-line format.
