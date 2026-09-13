- No change to `setuid`, `setgid`, `setresuid`, `setresgid`, or
  `capset` — this slice's probes confirm all five already return `-1`
  correctly on failure.
- No bundling with the `capget` tuple-deviation capture or the
  `getpgrp` raise capture.
