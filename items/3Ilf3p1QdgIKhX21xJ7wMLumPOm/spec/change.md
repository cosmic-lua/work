Decide whether the builtin `rm` in cosmo's `system()`/`_cocmd`
should honour `-r`/`-f` (upstream jart/cosmopolitan behaviour is the
reference; check `tool/build/cocmd.c` or wherever the builtin
lives) or whether the three tests should use `unix.rmrf`-style Lua
cleanup instead; do the smaller one that stops the leak, and add a
test that asserts the temp directory is gone after the suite's
cleanup.
