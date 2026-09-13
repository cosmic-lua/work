Retype `unix.getpgrp` in `tool/net/definitions.lua` from
`@return integer|nil pgid` (+ the `error`/`errno` lines) to a bare
`@return integer pgid`, dropping the failure-tuple lines entirely (no
reachable failure branch), following the `path.join` precedent (#276).
In a follow-up cosmic-side change (landed separately, per this repo's
own convention of never bundling a contract change with a wrapper
fix), update `cosmic/proc/init.tl`'s `getpgrp()` to drop the now-needless
`assert` once the type is a bare `integer`.
