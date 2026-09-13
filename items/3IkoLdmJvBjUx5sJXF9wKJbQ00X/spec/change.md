Decide in refinement, then build: either a spawned-binary test declares
its dependency on the binary (a `reads:` form the make rule honours,
so `o/bin/cosmic` becomes a prerequisite of the test record), or the
test rule for every `*_test.tl` under `_make/` and `_cli/` gains
`o/bin/cosmic` as a prerequisite by position. Whichever way, the
measured sequence above must re-run the test after an engine rebuild,
and a test that does not spawn the binary must not be re-run by an
unrelated engine change (measure `_make/fixtures_test.tl` and one pure
unit test, e.g. `cosmic/string_test.tl`).
