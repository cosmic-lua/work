Make both parsers in `cosmic/quicksand/proxy/http.tl` refuse a port
they cannot represent, the way `cosmic/url.tl:134` and `:280` already
do. Measured now: `wc -l cosmic/quicksand/proxy/http.tl` is 324 (176
lines of headroom under the 500-line cap) and
`cosmic/quicksand/proxy/http_test.tl` is 190.

- `parse_connect_target` (`:103-107`): after
  `local h, p = t:match("^([^:]+):(%d+)$")`, convert with
  `math.tointeger(tonumber(p))` into a local, and `return nil` when the
  conversion yields nil or the value is outside `1..65535`. The
  function already returns `nil` for an unparseable target and the
  caller already answers `http.BAD_REQUEST` on it
  (`serve.tl:178-180`), so this needs no new failure path.
- `parse_absolute_uri` (`:126-131`): same conversion and same range
  test on the `hp:match("^([^:]+):(%d+)$")` port; `return nil` instead
  of building an `AbsoluteUri` whose `port` field is nil.
  `serve.tl:221-223` already answers `BAD_REQUEST` for a nil return.
- Add both cases to `cosmic/quicksand/proxy/http_test.tl`: a
  19-nines port and a `70000` port, for each of the two parsers,
  asserting nil; plus the `example.com:443` control asserting 443.
