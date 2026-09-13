`tool/lua/test_unix_misc.lua`: fall back to `os.tmpname()`'s directory
(or `/tmp`) when `TMPDIR` is unset, the same one-line fix #363 applied
to `test_slurp_ranges.lua`. Test assertions unchanged.
