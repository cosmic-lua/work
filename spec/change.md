Give `lfetch.o` its missing header dependencies without re-admitting
`lfetch.c` into `TOOL_NET_SRCS` (the Mbed TLS 3.6 exclusion is
deliberate and stays). The least mechanism that makes an edit to
`fetch.inc` rebuild `lfetch.o` wins — e.g. an explicit dependency line
beside the module list in `tool/lua/BUILD.mk`
(`o/$(MODE)/tool/net/lfetch.o: tool/net/fetch.inc ...` for the headers
`lfetch.c` includes), or wiring `lfetch.c` into whatever list mkdeps
scans without changing which package compiles/links it. Investigate
which of the two the build system's own conventions prefer before
choosing; the repo keeps diffs surgical.
