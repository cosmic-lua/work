- No change to `setpgrp`, `setpgid`, `getpgid`, `getsid`, `setsid`, or any
  other `LuaUnixRc0` caller — each has a real failure path.
