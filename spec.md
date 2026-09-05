## Change

Two costs every agent that added a file paid today. First, the
coverage ratchet fails a new file with no `.cosmic-coverage` row, but
the failure line does not print the row to paste, so the agent ran
the gate once to learn a row was needed and once more to confirm the
hand-edit. Make `--make coverage` print, for each file with no row
and each declined row, the exact `["<file>"] = {["covered"] = N,
["total"] = M},` line the ratchet measured, and say in the verdict
that pasting it is the fix outside CI (the `--baseline` refusal stays).
Second, two tests failed on a wall-clock second boundary (a
committer-date window in `_work/refs_test.tl`, since fixed, and the
cache patch stamping its own `os.time()` beside a commit fast-import
had already dated). Add to `docs/guides` the testing rule: a test
never compares two readings of the clock; it fixes the date it writes
(`GIT_COMMITTER_DATE`, or the value the code under test stamped) and
asserts against that. Name both cases as the evidence.
