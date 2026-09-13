Land the 3 units (`sqlar stmtrand uint`) in the sqlite extension
registry, the same rule #356 (item 3If5rH0S) and batch 2 (#370) used:
add each to `THIRD_PARTY_SQLITE3_A_SRCS`/`_OBJS`, declare its init in
`extensions.h`, append it to the registry (`extensions.c`) and the
`---@alias lsqlite3.Extension` union in `definitions.lua`, against
`master` of cosmic-lua/cosmopolitan, green on `make -j$(nproc)
o//tool/lua/test`, with the size delta in the PR body. No
`MARKER_STEM` override needed — all three keep their shell.c stem.
