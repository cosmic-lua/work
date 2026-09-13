Resolve the proxy by scheme, the way every other client does: an
`https://` request reads `https_proxy` then `HTTPS_PROXY`; an `http://`
request reads `http_proxy` (see the httpoxy note below on the uppercase
form). An explicit `proxy` option still wins over both, unchanged.

Honour `no_proxy`/`NO_PROXY` as a comma-separated host suffix list, so a
caller can exempt a host without unsetting the proxy for the process.

Update `tool/net/definitions.lua` in the same commit — its "Environment
variables" block for `Fetch` currently documents only
`http_proxy`/`HTTP_PROXY`, and that block is the single source of truth
cosmic generates its Teal declarations from.

Treat the uppercase `HTTP_PROXY` question as its own decision rather
than folding it in silently: dropping it is a behaviour removal that
would break a caller relying on it today, and keeping it preserves a
known CVE's precondition. State which was chosen and why in the commit
message. Adding `HTTPS_PROXY` does not depend on resolving it.

Add tests covering: an `https://` request picking up `HTTPS_PROXY`, an
`http://` request not picking it up, the explicit option overriding the
environment, and a `no_proxy` host bypassing a set proxy.
