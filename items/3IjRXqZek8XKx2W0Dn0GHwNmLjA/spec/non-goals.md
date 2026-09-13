- Every other `lunix.c` binding keeps its contract, including
  `unix.kill`/`unix.killpg` (already exact — ESRCH/EPERM are genuinely
  environmental there, per this item's rows 1-2) and
  `unix.sigprocmask` (the sibling class-1 capture, filed separately as
  `3IjRZ9hD9NrStsAnyhMzwK6ZzAh`).
- No change to `unix.sigaction`'s own inline `1 <= sig && sig <= NSIG`
  check (it correctly excludes 0, since installing a handler for "no
  signal" is meaningless) — `raise`'s domain is wider by exactly the
  value that makes it behave like `kill`.
- No cosmic-side edit and no cosmos pin bump — the sibling consumption
  slice, blocked on this one landing.
