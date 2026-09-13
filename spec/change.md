In both files, change each restore call's argument from the saved
value directly to its `.handler` field — e.g.
`unix.sigaction(SIGINT, oldint)` → `unix.sigaction(SIGINT, oldint.handler)`
— at every call site listed above. No other change; this is the same
one-line fix `tool/lua/test_unix_misc.lua` already applied in #338 for
its own consumer.
