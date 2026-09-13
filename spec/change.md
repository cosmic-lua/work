`_make/generate.tl` `sources()`: every early `return` after
`seed.run` succeeds goes through `seed.cleanup()` first (a local
`fail(msg)` closure that cleans and returns `nil, msg`, or wrap the
generator loop in a function whose result is inspected after an
unconditional cleanup). `_make/seed.tl` `should_seed`: also true when
`SEED_DIR` exists but `o/_types/types_gen` is absent, so a stale seed
is re-run rather than trusted.

`_make/generate_test.tl`: a fixture whose stub generator fails after
the seed ran asserts `o/_types/types_seed` is absent afterwards and
the failure message survives.
