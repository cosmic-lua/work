Give `unix.nanosleep`'s failure path a return arity that never
overlaps a real success value's position — e.g. append the
EINTR-remaining-time values as genuinely separate TRAILING slots after
a clean `nil, err, errno` triple, rather than reusing the "remaining
seconds"/"remaining nanoseconds" slots for the error string/errno.
Update `definitions.lua`'s annotation to match. This is the reference
fix the sibling captures (`unix.sigaction`, `unix.setitimer`,
`unix.gmtime`, `unix.localtime`) are blocked on — land this one first,
then apply the equivalent shape to each sibling (or record a decision
that this shape is accepted as-is, in which case unblock and close the
siblings as "won't fix, documented" instead).
