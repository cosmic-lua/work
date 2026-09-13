- No change to any other `unix.getsockopt`/`unix.setsockopt` overload
  — this is scoped to the `SO_LINGER` branch alone.
- No change to `tool/net/definitions.lua` — its `@overload` annotation
  for this case is already correct; the C implementation just wasn't
  honoring it.
- No re-litigating the sockets/network census's classification work —
  this is a success-path arity bug, unrelated to nil-admission.
