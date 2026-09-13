Make the test's pledge case survive tracing without weakening what it
asserts: either the child pledges with `stdio` retained when tracing
is on (detectable via the `--ftrace` flag's environment or a
`unix.getenv` the harness sets), or the pledge case moves into a
separate script the floor collector runs untraced while the rest of
`test_unix_misc.lua` is traced. Then remove the entry from the
collector's `SKIP` table and rebaseline the floor
(`COVERAGE_BASELINE=1`), so the gained functions ratchet in.
