`tool/lua/test_slurp_ranges.lua`: fall back to `os.tmpname()`'s
directory or `/tmp` when `TMPDIR` is unset, one line; the test's
assertions are unchanged.
