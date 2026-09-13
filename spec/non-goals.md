- No change to `unix.raise` — filed separately.
- No change to `unix.sigaction`/`unix.sigpending` — their nil paths are
  handled in their own captures (sigaction) or the parent item's
  class-3 note (sigpending).
