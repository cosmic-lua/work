Not attempting to change or extend `tl` itself (no upstream patch) —
this outcome works with what the pinned `tl` already exposes, or with
cosmic's own AST layer once it exists, never by adding new plumbing to
`tl.lua` via the carried-patch mechanism. This session's findings
confirm the gap is structural (a type-report layer used for a
binding-identity purpose it isn't shaped for), not a small missing
annotation `tl.lua` could plausibly grow — so this non-goal is
reaffirmed, not merely still assumed.
