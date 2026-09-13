- no wall-clock timeout and no C-hang detection — that requires child
  processes (the crash-isolation child, `cosmic.child`), not a hook.
- no change to iteration counts, seeds, or reporting beyond the one
  added field.
- no change to `cosmic/coverage/**` and no C-side (cosmo.cov) budget —
  the cross-repo composition is its own capture, not this slice.
