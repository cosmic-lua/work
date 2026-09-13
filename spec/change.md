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
