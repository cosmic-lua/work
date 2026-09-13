Not changing the two-level `GITBOARD_PROVIDER_TOKEN_ENV` indirection, the
closure-held token, or any existing refusal's wording. Not adding a
retry, a fallback credential, or proxy discovery — `activate` still
installs what the caller named or nothing. Not changing `deactivate`.
Not fixing `cosmo.Fetch`'s proxy resolution; that is the cosmopolitan
item and this change must not paper over it by setting environment
variables of its own.
