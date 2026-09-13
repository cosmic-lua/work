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
