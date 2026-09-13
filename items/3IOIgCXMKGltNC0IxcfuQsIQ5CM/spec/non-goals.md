No streaming pooling, proxy pooling, HTTP/2, pipelining, TLS 1.3 upgrade,
resumption cache, API-wide default change, new retry policy, HEAD bug repair,
new HTTP parser, or compatibility-policy decision. Preserve Fetch's 4-value
success / 3-value failure and FetchReader read/read_until/close/GC contracts.
Only the explicit TLS keepalive capability changes its documented availability,
in its own definitions.lua update and runtime release.
