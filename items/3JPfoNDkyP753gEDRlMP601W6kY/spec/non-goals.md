Not changing the pin format, the trust root, or what is verified — the sha256
check stays exactly where it is on every path. Not caching build outputs, only
the fetched runtime binary.

Not introducing a cache that survives the machine, and not adding a cleanup
policy beyond whatever the simplest correct implementation needs.
