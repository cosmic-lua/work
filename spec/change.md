`_make/policy_test.tl`: one end-to-end fixture test for
`write_baseline` — a small committed baseline and a run whose rows
move in both directions (at least one row raised, a different number
lowered, e.g. 1 raised and 2 lowered), capturing what `write_baseline`
prints and asserting the per-row `RAISES`/`LOWERS` lines AND the
closing summary's counts read `2 row(s) lowered, 1 raised`. Choose
unequal counts so a swapped argument at either seam fails the
assertion. Use whatever `_make/policy_test.tl` already has to construct
a baseline and a coverage result in a `TEST_TMPDIR`; if `write_baseline`
cannot be driven without a real coverage run, split the I/O so its
pure core (rows in, lines out) can be, and test that — `wrote_summary`
and `narrate_moves` stay as they are.
