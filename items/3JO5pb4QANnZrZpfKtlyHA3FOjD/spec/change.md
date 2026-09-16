`new --spec-file` derives `touches` from the spec's `## Change`, but `spec`
does not re-derive it. A respec that moves which files the Change names
leaves `touches` pointing at the old set, so `show`'s `tight:` line and the
builder brief's `## Measured at brief time` section both measure files the
item no longer touches — and stay silent about the ones it does.

Measured 2026-09-16, on «sYow_SyfM», immediately after the derivation landed
as `1b632f348`:

- The item's Change originally named `_work/gitworktree.tl`. A builder
  bounced: the named file was wrong, and the real seam is
  `_work/worktree_runtime.tl`.
- `spec sYow_SyfM FILE --base BASE` replaced the Change with one naming
  `_work/worktree_runtime.tl`, `_work/worktree_runtime_test.tl` and
  `_work/gitworktree.tl`.
- The regenerated builder brief still measured ONE file:

        ## Measured at brief time (<tree>, 28e4d582c)
        _work/gitworktree.tl  426 lines

  — the stale pre-respec list. A manual `set --touches` with all three was
  needed before the brief measured what the corrected spec actually names.

The consequence is worst exactly when it matters most. A respec that moves
the Change's files is the case where a builder most needs an accurate line
budget, because the files are ones nobody has looked at yet — and it is the
one case the derivation does not cover.

Re-derive `touches` in `spec` the same way `new` does, when the caller did
not state it otherwise. `spec` already replaces the whole spec sidecar, so
the derived list should follow the prose it derives from rather than
surviving it.

Settle one question while building: an item whose `touches` was set by hand
with `set --touches`, and is then respecced. Re-deriving would silently
discard the caller's explicit list; not re-deriving reproduces this bug for
that item. Prefer re-deriving and say so in `help spec`, since `set` remains
available to restate an explicit list afterwards — but decide it deliberately
and record the choice.

Regression: an item filed with a Change naming file A, respecced to a Change
naming file B, reports B in `show`'s path measurement and in a builder
brief's measured section, and no longer reports A.
