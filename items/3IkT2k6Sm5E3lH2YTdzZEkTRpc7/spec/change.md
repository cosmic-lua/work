`tool/net/help.txt`, the `unix.Stat:birthtim()` example only: close the
format string, and print the zone offset as sign, hours, minutes
computed from the magnitude:

```lua
local off = t.gmtoffsec
local sign = off < 0 and "-" or "+"
local hh = math.abs(off) // 3600
local mm = math.abs(off) // 60 % 60
-- ... '%s%.2d%.2d' % {sign, hh, mm} in the format string's zone field
```

(adapt the names to the example's existing locals; the point is
`math.abs` on both terms and an explicit sign). Confirm by hand with
`Write` swapped for `print` and `unix = require 'cosmo.unix'` prepended
(redbean has `unix` as a global; plain `lua` does not), under
`TZ=UTC`, `TZ=Asia/Kolkata` (+0530) and `TZ=America/St_Johns` (-0230 in
summer), comparing against `date -d @<secs> '+%FT%T%z'`. Documentation
only.
