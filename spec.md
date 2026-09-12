## Evidence

`cosmo.Fetch` resolves a proxy from the environment at
`tool/net/lfetch.c:884-890`:

    if (!proxyarg) {
      proxyarg = getenv("http_proxy");
      if (!proxyarg)
        proxyarg = getenv("HTTP_PROXY");

That is the whole list. `HTTPS_PROXY`/`https_proxy` are never consulted,
and neither is `NO_PROXY`/`no_proxy`. The lookup is also
scheme-agnostic: the `usingssl` flag is already in scope twelve lines
above, but an `https://` request takes the same `http_proxy` value as an
`http://` one.

Every other mainstream client splits these — curl, wget, Python
requests/urllib, Go's `net/http`, Node, Java. `HTTPS_PROXY` is the
variable that matters in practice now that almost all traffic is TLS,
and it is the one `Fetch` ignores.

**Observed breakage, and why the failure mode is the bad one.** In a
Claude Code remote session the agent proxy is published as `HTTPS_PROXY`
and `https_proxy` only; `HTTP_PROXY` and `http_proxy` are unset.
cosmic-lua/work's GitHub client (`_work/api.tl` through
`cosmic.fetch`) therefore connected DIRECTLY to `api.github.com`,
bypassing the proxy that injects credentials, and every call returned:

    GET /user: HTTP 401: Bad credentials
    GET /repos/cosmic-lua/work: HTTP 401: Bad credentials

Setting `HTTP_PROXY` to the same value the session already published as
`HTTPS_PROXY` (plus `SSL_CERT_FILE` for the proxy's CA) fixed it
outright:

    via proxy: GET /repos/cosmic-lua/work status=200

A request that should be proxied is silently sent direct instead. It
does not fail as a proxy error — it succeeds at the socket level and
fails much later with a symptom ("Bad credentials") that points at the
credential rather than the transport. That cost roughly an hour of
debugging aimed at the wrong layer.

**A second, separable concern found while reading the same block.**
Honouring uppercase `HTTP_PROXY` is the "httpoxy" hazard
(CVE-2016-5385): in a CGI environment, request headers arrive as
`HTTP_*` variables, so a client sending a `Proxy:` header sets
`HTTP_PROXY` in the process. curl deliberately ignores uppercase
`HTTP_PROXY` for exactly this reason while still honouring uppercase
`HTTPS_PROXY`. `Fetch` today honours the unsafe spelling and ignores the
safe one — precisely inverted.

## Change

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

## Non-goals

Not changing `Fetch`'s return shape, error kinds, or the `proxy` option's
format — this is environment resolution only, and the fallible-tuple
contract is untouched. Not adding proxy authentication beyond the
`user:pass@host` form the option already supports. Not changing
`SSL_CERT_FILE`/`SSL_NO_SYSTEM_CERTS` handling.

## Access

cosmic-lua/cosmopolitan, read and write on a branch. A cosmic-side type
regen follows from the `definitions.lua` change and lands separately on
the next pin bump; no write to cosmic-lua/cosmic from this item.
