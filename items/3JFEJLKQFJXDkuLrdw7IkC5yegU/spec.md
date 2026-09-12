## Evidence

Two matching defects in `IsNoProxyHost` (`tool/net/fetch.inc:17-41`),
found by `«kcoY_pv9c»`'s review (PR #396) and reported non-blocking.

**1. An empty `no_proxy` shadows a populated `NO_PROXY`.** The lookup is
`getenv("no_proxy")` and, only if that is NULL, `getenv("NO_PROXY")`. An
empty string is not NULL, so the lowercase spelling set to `""` suppresses
the uppercase one entirely. Verified:

    no_proxy="" NO_PROXY=fallback.com   ->  fallback.com NOT exempted

For the PROXY variables this shape is conventional — empty means "no
proxy", as curl does — so it is right there. For `no_proxy` it is
surprising, and `definitions.lua` states the precedence rule only for the
proxy variables ("the lowercase spelling wins when both are set"), never
for `no_proxy`.

**2. Glob and port entries are silently inert.** Only a lone `*` is a
wildcard; `*.example.com` matches nothing, and `example.com:8080` matches
nothing (curl supports ports). The entry is neither honoured nor
rejected — it is simply skipped.

This is not hypothetical: the container this was found in publishes

    NO_PROXY=...,*.svc.cluster.local,...

Real-world lists usually pair a glob with its bare-suffix form (this one
does, so the practical exposure here was small), but where they do not,
the failure direction is the bad one: traffic goes to the proxy the
operator meant to bypass, silently.

The documented rule at `definitions.lua:2986-2991` does not promise glob
support, so this is a gap between what operators write and what is
honoured, not a contract violation.

## Change

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

## Non-goals

Not changing the scheme split, the proxy-variable precedence, or the
explicit `proxy` option's exemption from `no_proxy` — all three are
settled by `«kcoY_pv9c»`. Not changing `Fetch`'s return shape or error
kinds. Not adding CIDR matching.

## Access

cosmic-lua/cosmopolitan, read and write on a branch; no other repository.
