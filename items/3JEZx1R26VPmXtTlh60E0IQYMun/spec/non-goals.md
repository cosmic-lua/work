- The concurrency model (threads, fork-per-connection, a poll loop) is
  G7's other half and is NOT decided here: `cosmic.http` v1 serves one
  connection at a time, keep-alive within it, and the loop shape is a
  child research item, not a drive-by.
- TLS: `wrap_server` («Kjv6_ep9u») is the primitive; `cosmic.http`
  takes any `stream.Reader`+`Writer` connection so TLS slots in later.
- HTTP/2, WebSocket: not in this container.
- No `cosmic.htmx` coupling inside `cosmic.http`: nothing in the server
  reads an `HX-*` header.
