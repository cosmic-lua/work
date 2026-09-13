None yet — **blocked**. Ready when:

```
bin/gitboard show <handle-for-cosmic-lua/cosmopolitan-144-if-tracked>
```
prints a `completed`/`landed` resolution, or equivalently:
`gh issue view 144 --repo cosmic-lua/cosmopolitan --json state`
prints `"state": "OPEN"` → not ready; prints `"CLOSED"` with the
IPv6 binding work merged → ready to refine into a real `## Change`.

Once #144 lands and a cosmos release carrying it is pinned
(`3p/cosmos/cosmos_pin.tl` bumped, `bin/cosmic --make fetch`), the
follow-up spec's `## Change` is, per the original issue's own scoping
(kept here as the shape to refine against, not as a committed plan):

- `cosmic/ip.tl`: add an `"inet6"` `Family` value; extend `parse`/
  `format`/`lookup` to accept and produce it; extend `Cidr` for v6
  prefixes. `Addr` stays the one currency (per `ip.tl`'s own header,
  already documenting this as the planned extension point).
- `cosmic/net/*.tl`: `dial`, `connect`, `bind`, `getsockname`/
  `getpeername`, `recvfrom`/`sendto` accept/return v6 `Addr`s;
  `dial`'s host-as-string-or-Addr contract (api-review-2, #588) was
  reserved for exactly this, per `cosmic/net/init.tl`'s header.
- `cosmic/fetch` (or wherever the SSRF/`allow_private` guard lives):
  verify v6-literal host classification once `ip.parse` admits them.
- New hermetic tests dialing `::1` (loopback), alongside the existing
  `test_dial_rejects_ipv6_literals` in `cosmic/net/connect_test.tl`,
  which will need rewriting (it currently pins the rejection as
  correct behavior — a "known limitation" test, not yet marked so
  explicitly, that a real fix must deliberately invert).

This has to be split into per-module specs (`ip.tl`, `net/*.tl`,
fetch/SSRF) once it is unblocked — combined, it is exactly the kind of
multi-file "and" the spec bar says to cut apart, and the ~400-line
smell threshold likely applies across the three areas together.
