In `LuaUnixGetsockopt`'s `SOL_SOCKET`/`SO_LINGER` branch
(`third_party/lua/cosmo/lunix.c:2139-2148`), change `return 1;` to
`return 2;` so both pushed values (`seconds`, `enabled`) reach the
caller, matching the existing inline comment and the
`tool/net/definitions.lua:6277` `@overload` annotation exactly (no
annotation change needed — the annotation was already correct; only
the C return count was wrong).
