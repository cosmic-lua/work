- No change to which flags `lfetch.c` compiles under or which binary
  links it — the Mbed TLS 3.6 arrangement `tool/net/BUILD.mk:7-8`
  documents is untouched.
- No general mkdeps rework; this is one object's missing edges.
