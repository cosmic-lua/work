## Evidence

`«kcoY_pv9c»` (PR #396) split proxy resolution by scheme in two places:
`LuaFetch` (`tool/net/fetch.inc`) and `LuaFetchStream`
(`tool/net/lfetch.c:883-901`). The two blocks are byte-identical in logic.

All five new tests exercise `Fetch` only. `LuaFetchStream`'s copy is
covered by inspection alone, and `tool/lua/test_fetchstream_edge.lua` has
no environment-resolution case at all. So the two blocks are free to
diverge: an edit to one, or a fix applied to only one, produces no test
failure. That is exactly the shape of the bug `«kcoY_pv9c»` was filed
for — its own evidence named one of the two sites and missed the other,
and the builder found the second only by live probing.

Reported by that item's reviewer as a gap rather than a defect; the spec
named no function, so `Fetch`-only coverage satisfied it literally.

**Separately, a superseded test now carries a credential hazard.**
`tool/lua/test_fetch_proxy.lua:349-358` (`test_http_proxy_env_var`,
`git blame` ccb91c3a5, untouched by #396) asserts nothing. It reads
`http_proxy` and, when set, prints its raw value — which may carry a
`user:pass@` prefix — into the test log, which in CI is build output.

`«kcoY_pv9c»` added `test_http_proxy_env_var_used`, which covers the
behaviour the old one gestured at. The old test is now dead weight whose
only remaining effect is writing a possibly-credential-bearing URL to a
log. Deleting an existing test was outside that item's Change.

## Change

Give `LuaFetchStream` the environment-resolution coverage `Fetch` has:
`FetchStream` picking up `HTTPS_PROXY` for an `https://` request, not
picking it up for an `http://` one, and a `no_proxy` host bypassing a set
proxy. Keep them hermetic — a local listener, never an ambient proxy — so
they pass with the container's proxy variables both set and unset, the way
`«kcoY_pv9c»`'s tests do.

Delete `test_http_proxy_env_var`. State in the commit message that
`test_http_proxy_env_var_used` supersedes it and that the deletion also
removes a credential-in-log hazard, so the removal reads as deliberate
rather than as lost coverage.

## Non-goals

Not changing any resolution behaviour — this is coverage and one
deletion. Not refactoring the two duplicated blocks into one (worth
considering, but it is a structural change to a fork-local include and
belongs to its own item with its own mergeability argument). Not touching
`definitions.lua`.

## Access

cosmic-lua/cosmopolitan, read and write on a branch; no other repository.
