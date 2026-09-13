- No change to `libc/calls/sigpending.c` — its EFAULT/ENOSYS paths are
  correct for the general-purpose libc function; only the Lua binding,
  which never triggers either, is tightened here.
- No cosmic-side edit — no caller exists (`grep -rn
  'unix\.sigpending' cosmic/` is empty).
- No change to `unix.sigsuspend` or `unix.sigprocmask` — separate
  bindings, separate captures.
