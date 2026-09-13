- Do not change `LuaResolveIp`'s return contract — it is frozen and
  stays exactly `int32|nil, string`. The new dual-stack resolver is
  strictly additive.
- Do not touch `unix.sendto`'s documented two-positional-integer v4
  calling convention (`unix.sendto(fd, data, ip:uint32, port:uint16[,
  flags])`) — it is unchanged; the new table form is additive at the
  same argument position, not a replacement.
- Do not add IPv6 support to `tool/net/getadaptersaddresses.c` (Windows
  adapter-address enumeration) — that file already handles
  `AF_INET6` for a different purpose (listing local interfaces) and is
  out of scope here.
- Do not implement a fully general `getifaddrs`-style v6 interface
  enumeration — only outbound/inbound socket addressing and DNS
  resolution, per the issue's own ask.
