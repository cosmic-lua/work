`tool/lua/test_signal.lua` only, appended after the existing "An
uninterrupted nanosleep..." block (currently the last block before
`print("PASS")`):

```lua
-- An interrupted nanosleep shares two return slots with its own
-- success values (tool/net/definitions.lua): the error string lands
-- where the success remainder-nanoseconds would sit, and the errno
-- where nothing sits on success. Pin that shape live.
do
  unix.sigaction(unix.SIGALRM, function() end)
  unix.setitimer(unix.ITIMER_REAL, 0, 0, 0, 200000000) -- fires once, ~200ms
  local remseconds, remnanos, eno, eintr_s, eintr_ns = unix.nanosleep(2, 0)
  assert(remseconds == nil,
    "an interrupted sleep must report nil in the slot 0 occupies on success")
  assert(type(remnanos) == "string",
    "the error string must land in the slot the remainder occupies on success")
  assert(eno == unix.EINTR, "errno must be EINTR, got " .. tostring(eno))
  assert(math.type(eintr_s) == "integer" and math.type(eintr_ns) == "integer",
    "the kernel's own remainder must follow the errno")
  unix.sigaction(unix.SIGALRM, unix.SIG_DFL)
end
```
