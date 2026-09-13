- No accept loop, no fd reads, no response serialization — a status
  line is `"HTTP/1.1 " .. code .. " " .. cosmo.GetHttpReason(code)` in
  Lua and needs no C.
- No `ParseHttpRange` yet (the static-file child decides whether Range
  is in scope; binding it then is a separate, tiny change).
- Do not touch `tool/net/redbean.c`.
