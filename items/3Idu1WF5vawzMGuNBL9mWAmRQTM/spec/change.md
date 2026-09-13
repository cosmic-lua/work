One new file, `tool/lua/test_fetch_proxy.lua`, from
`test/tool/net/lfetch_test.lua`, with this prelude added above the
existing `local Fetch = Fetch or require("cosmo").Fetch` line:

```lua
local cosmo = require("cosmo")
local unix = require("cosmo.unix")
local ParseIp = cosmo.ParseIp
```

Split the body in two on the way over:

1. The proxy block plus the local-error-handling tests
   (`test_ssrf_blocks_*`, `test_invalid_scheme`, `test_bad_method`,
   `test_negative_maxresponse_rejected`) — all self-contained, no
   external network — land in `test_fetch_proxy.lua`'s `main()` test
   list.
2. The `httpbin.org`/`github.com` tests are NOT ported by this slice.
   They test real value (redirect-chain behavior, status-code mapping,
   a real regression against long `Location` headers) but need a
   verified network policy for `o//tool/lua/test` first — confirm
   whether `pr.yml`'s lane that builds/runs `o//tool/lua/test` has
   network access, and if not, whether a `SKIP`-on-no-network pattern
   (as `tool/lua/test_fetch_unix_proxy.lua`'s own header already notes:
   "Functional proxy tests require forking and may not work in all CI
   environments") is the fork's convention here. Land that as ITS OWN
   follow-up item once the policy is known, rather than guessing here.
   `test_response_too_large_error_message` belongs in THIS bucket, not
   in item 1: despite being one of `lfetch_test.lua`'s local-error-
   handling tests, its assertion path requires actually connecting to
   and reading a real response from `https://httpbin.org/get` —
   `tool/net/fetch.inc:688` enforces `maxresponse` only once bytes
   arrive on the wire — so it shares this bucket's network-policy
   blocker, not item 1's self-contained-and-ready status. It also
   carries a SECOND, independent blocker on top of that: even with
   network reachable, `tool/net/fetch.inc:696`'s
   `"response too large (max %I bytes)"` format string uses an
   unsupported `%I` conversion, so the byte count never renders and the
   test's `err:match("max %d+ bytes")` assertion never matches
   (tracked as its own item, `3IiEMurIlcpbXdQ9CUhYmGK2Sei`). Porting
   this test needs BOTH the network-policy follow-up above AND that
   format-string fix landed first.

`tool/lua/BUILD.mk:222-251` gets one new three-line rule
(`o/$(MODE)/tool/lua/test_fetch_proxy.ok: o/$(MODE)/tool/lua/lua.dbg
tool/lua/test_fetch_proxy.lua`, run, `@touch $@`) and one new
`TOOL_LUA_TESTS` line.
