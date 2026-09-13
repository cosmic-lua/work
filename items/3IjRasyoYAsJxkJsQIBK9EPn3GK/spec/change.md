`tool/lua/test_unix_misc.lua` only, appended after the existing
(post-fix) `gmtime` block that `3IjRaU2dA8zH56DfC1og37HbOug` writes:

```lua
-- localtime has no dedicated coverage today (`grep -c localtime
-- tool/lua/test_unix_misc.lua` reports 0 before this change). Pin
-- both paths against the unix.BrokenDownTime table shape
-- 3IjRaU2dA8zH56DfC1og37HbOug introduced for gmtime and localtime
-- together (same LuaUnixTime C helper, tool/net/definitions.lua):
-- TZ=UTC makes the success path degenerate to gmtime's own answer so
-- it can be pinned without depending on the runner's zone.
unix.setenv("TZ", "UTC", true)
local lbdt = assert(unix.localtime(1657297063))
assert(lbdt.year == 2022 and lbdt.mon == 7 and lbdt.mday == 8
  and lbdt.hour == 16 and lbdt.min == 17 and lbdt.sec == 43,
  "localtime(TZ=UTC) must match gmtime's breakdown for the same timestamp")

local lbad, lerr, leno = unix.localtime(9223372036854775807)
assert(lbad == nil, "localtime of an unrepresentable timestamp must report nil")
assert(type(lerr) == "string", "the error must be a string")
assert(leno == unix.EOVERFLOW, "errno must be EOVERFLOW")
```
