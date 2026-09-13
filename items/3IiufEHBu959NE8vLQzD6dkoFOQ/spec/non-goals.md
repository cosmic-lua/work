- No re-litigation of `unix.nanosleep` (the already-known sibling instance
  of this shape) or of `path.join`/`unix.clock_gettime` (#276/#277).
- No change to `unix.wait`'s semantics (WNOHANG, signal semantics, the
  `-1`/pid argument reading) — only the tuple shape is in scope.
- No touching any other binding in the census's process/scheduling slice —
  all 11 siblings were verified exact and carry no capture.
