- Chunked request bodies, streaming/chunked responses, SSE — the
  streaming child.
- Routing, forms, cookies, static files — their own children.
- Concurrency: one connection at a time. No threads, no fork, no poll.
- TLS. `Server` takes a `net.Socket` listener only in v1.
- Reading `HX-*` anything.
