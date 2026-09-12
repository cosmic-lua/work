## Evidence

`_work/apiauth.activate()` reports success as soon as it has a token to
install. It never checks that the token works, so a misconfigured or
unroutable credential is discovered later, once per call, as a status
code far from its cause.

Exercised live in a Claude Code remote session — the first end-to-end run
of gitboard's provider transport against real GitHub:

    activate(GH_TOKEN): true (ok)
    GET /user: HTTP 401: Bad credentials
    GET /repos/cosmic-lua/work: HTTP 401: Bad credentials

`activate` said yes; every call then failed. The actual cause was not the
token at all: `cosmo.Fetch` honours only `http_proxy`/`HTTP_PROXY`, and
that session publishes its agent proxy as `HTTPS_PROXY` only, so the
request went direct to `api.github.com` instead of through the proxy that
makes the ambient credential valid. Pointing `HTTP_PROXY` at the same
value turned the identical call into `status=200`. (The cosmo-side fix is
its own item in cosmic-lua/cosmopolitan; this item is about the
diagnosis, which is worth having even once that lands, since a plainly
wrong or expired token produces the same 401.)

"Bad credentials" sent the debugging at the credential for about an hour
when the transport was at fault. A caller who activates and then runs
`verdict accept` gets this as `landing failed (... HTTP 401 ...), land it
by hand` on the verdict line, which names neither cause.

The recipe that works in this environment is also recorded nowhere:

    GITBOARD_PROVIDER_TOKEN_ENV=GH_TOKEN
    HTTP_PROXY="$HTTPS_PROXY"
    SSL_CERT_FILE=/root/.ccr/ca-bundle.crt

Every future session re-derives it or gives up.

## Change

Give `activate` a preflight: one authenticated read (`GET /user` is the
cheapest) before it reports success. On a non-2xx, install nothing,
restore the prior transport, and return `false` with a message that names
what was tried and the status — so a caller learns at activation that the
transport does not work, rather than at its first landing.

Have that message distinguish the two cases the 401 conflates, since they
have different repairs: a credential the provider rejects, and a proxy
that was expected but not used. A cheap, honest discriminator is whether
a proxy variable is set for the scheme actually in play — name it in the
message rather than diagnosing it, so the sentence stays true when the
cosmo-side fix lands.

Never put the token, or any value read from the environment, in that
message — `activate`'s existing refusals are careful about this
(they name only `GITBOARD_PROVIDER_TOKEN_ENV`) and the preflight must
stay equally careful. Name variables, statuses and URLs; never values.

Record the working activation recipe where a session will find it — the
module's own doc comment is the honest home, since that is what `--docs`
serves and what a caller reads before setting the variable.

Add cases: a preflight that fails installs nothing and leaves the codec
refusing exactly as before; a preflight that succeeds installs the
transport; the failure message contains no environment value. Use the
existing fake-transport seam — this needs no network.

## Non-goals

Not changing the two-level `GITBOARD_PROVIDER_TOKEN_ENV` indirection, the
closure-held token, or any existing refusal's wording. Not adding a
retry, a fallback credential, or proxy discovery — `activate` still
installs what the caller named or nothing. Not changing `deactivate`.
Not fixing `cosmo.Fetch`'s proxy resolution; that is the cosmopolitan
item and this change must not paper over it by setting environment
variables of its own.

## Access

cosmic-lua/work, read and write on a branch; no other repository.
