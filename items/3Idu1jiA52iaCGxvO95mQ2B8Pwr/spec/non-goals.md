- No binding change. `cosmo.FetchStream`'s chunked-decoder behavior on
  malformed input and its error/EOF signaling are frozen. If a ported
  assertion no longer holds against the fork's real behavior (the
  malformed-input tests already accept more than one outcome, e.g.
  "nil with error, or empty result, but not a crash" — see
  `test_stream_chunked_invalid_size`), that is evidence, never a reason
  to touch `tool/net/lfetch.c`.
- Do not touch `test/tool/net/**` or `test/tool/BUILD.mk`; retirement is
  `3IOCgtWA`.
- Do not touch `tool/lua/test_fetch_local.lua`; this is a new file
  alongside it.
- Do not fold this into the Fetch-proxy slice
  (`titled "salvage cosmo.Fetch's HTTP-proxy contract..."`, filed
  alongside this one) — `Fetch` and `FetchStream` are independent
  surfaces even though both live in `tool/net/lfetch.c`.
