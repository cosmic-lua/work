# _build/gitboard_pin_test.tl: declare `--- reads: bin/gitboard.pin` so a pin edit re-runs it

## Change

`_build/gitboard_pin_test.tl` reads `bin/gitboard.pin` (its `PIN` constant)
but carries no `--- reads: bin/gitboard.pin` header, so the runner reuses the
last recorded result across an edit of the pin: the #1852 review mutated the
sha to 63 characters and `--make test _build/gitboard_pin_test.tl` reported
the stale `PASS`, and after restoring the pin the stale `FAIL` was reused
until `o/_build/gitboard_pin_test.tl.test.*` was deleted by hand. AGENTS.md's
own rule ("a test that reads a file the graph cannot see declares it with a
`--- reads:` line") applies. CI runs from a fresh tree, so the PR lane is
unaffected; only a local re-run is.

Add the one header line before the first `local`, then show: edit the pin's
sha to 63 characters, `--make test _build/gitboard_pin_test.tl` goes red
without deleting any recorded result; restore, it goes green.

## Non-goals

- No change to what the test checks (shape, not value).
