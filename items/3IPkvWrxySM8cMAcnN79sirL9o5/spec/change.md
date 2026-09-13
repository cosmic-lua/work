For each of the 30 sites, copy the field into a local at the point of
use and guard the local, or restructure the branch so the field is read
once behind an existing guard. Where a field is genuinely always set by
the time it is read, say why in a comment beside the guard — do not
delete the guard and do not add a cast.

Where a record is filled in two phases (`_perf/peers/peers.tl:28`
`build_argv: {string} | nil -- compiled in setup when set`), consider
whether the two phases want two record types instead of one nilable
field, and decide it in this slice rather than deferring.
