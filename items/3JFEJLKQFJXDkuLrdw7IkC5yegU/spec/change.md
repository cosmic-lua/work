Decide and implement one behaviour for each, and document whichever is
chosen:

For the empty-value case: either fall through to `NO_PROXY` when
`no_proxy` is empty, or keep today's shadowing and state it explicitly in
`definitions.lua` alongside the proxy-variable precedence rule. Silence is
the one option to reject.

For entries the matcher cannot honour: at minimum support a leading
`*.` glob, since that spelling is common enough to appear in this
container's own configuration. A port suffix may reasonably stay
unsupported — say so in the docs rather than skipping it silently.

Update `tool/net/definitions.lua` in the same commit, as the
binding-contract convention requires.

Add cases for each behaviour chosen, including the empty-value precedence
and a `*.` entry matching a subdomain but NOT the bare domain (or
whichever rule is picked).
