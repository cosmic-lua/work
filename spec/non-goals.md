- No change to `unix.kill`/`unix.killpg` — both have a genuine
  ESRCH/EPERM environmental failure independent of the signal-number
  question.
- No change to `unix.sigprocmask` — filed as its own capture for the
  same doctrine.
