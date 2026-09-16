`gitboard brief builder ID` emits `<WORKTREE>` as an unfilled placeholder when
the preparation receipt that linked the claim to its checkout is no longer
available, even though the path is derivable: a worktree is named
`work/<handle>/<claim>` and the claim is recorded on the item.

Derive the worktree path from the item's own claim when no receipt is present,
and fall back to the placeholder only when the derived directory does not
exist. A caller emitting a brief for an item claimed earlier in the same
session then gets a filled brief instead of a hand-fill step.

Regression: emit a builder brief for an item whose worktree exists but whose
receipt is absent, and assert the brief carries the path and the verdict line
reads "nothing left to fill".
