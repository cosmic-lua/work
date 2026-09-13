- No change to `setpgrp`, `setpgid`, `getpgid`, `getsid`, or `setsid` —
  each has a real, demonstrated failure path (see sibling item
  `3IR2SFOqEXQ4luAS8FK0Km2AzEa`'s evidence).
- No change to any other niladic `unix.*` accessor outside `getpgrp`.
