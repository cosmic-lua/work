- No change to `setrlimit` — already a clean `true|nil, string?,
  unix.Errno?` 3-slot tuple with a single success shape, confirmed by
  this slice's probe (`o//tool/lua/lua -e 'print(require("unix").setrlimit(999999, 100, 100))'`
  → `nil	setrlimit: EINVAL: Invalid argument	22`).
- No change to any other multi-return binding in this slice (`chroot`,
  `unshare`, `setns`, `mount`, `unmount`, `pivot_root`, `pledge`,
  `unveil`, the four `landlock_*` bindings, `sysconf`, `uname`) — all
  confirmed exact 3-slot tuples with a single, unambiguous success
  value; see the parent item's summary table.
- No change to `cosmic/proc/rusage.tl` in this capture's own PR (see
  Change, above) — land the binding fix first; the cosmic-side
  simplification is a separate, later change once a pin bump carries
  this fix.
