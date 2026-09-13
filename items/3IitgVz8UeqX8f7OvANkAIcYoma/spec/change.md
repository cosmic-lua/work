One PR on cosmic-lua/cosmopolitan, two parts:

1. Put `tool/net/lfetch.c` into the scan without putting it back into
   `TOOL_NET_SRCS`'s object list: a source variable that the root
   `SRCS` aggregate sees (a `TOOL_LUA_*_SRCS` entry in
   `tool/lua/BUILD.mk`, the package that owns the object, or an
   `EXTRA_SRCS`-style hook if `build/definitions.mk` already has one),
   so `srcs.txt` lists it and `o/$(MODE)/depend` gains its edges; keep
   the object's explicit rule and its Mbed TLS flags exactly as they
   are; then delete the hand-listed `tool/net/fetch.inc` prerequisite
   and its comment at `tool/lua/BUILD.mk:40-45`, since `depend` now
   carries it.
2. A gate so the next filtered-out source cannot repeat this: a small
   test enrolled in `tool/lua/BUILD.mk` (own `@touch $@`) that reads
   `o/$(MODE)/srcs.txt` and asserts every `.c` under `tool/net`,
   `tool/lua` and `third_party/lua/cosmo` that has an object rule in
   this build appears in it, failing by path.
