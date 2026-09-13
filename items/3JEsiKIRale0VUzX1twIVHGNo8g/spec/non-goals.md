`_work/spec.tl`'s `READY_SECTIONS` and every other code path — this is
prose inside Teal string constants plus the test expectations that move
with it.

`## Evidence`. Its move out of the spec is settled by D47 in
cosmic-lua/cosmic but depends on a mechanism that does not exist yet, so
templates keep teaching it and nothing about its handling changes.

The `## Access` convention itself, which `_work/gitowner.tl` and
`_work/gitready.tl` machine-read.

Dropping `## Acceptance` from the fixtures in `_work/action_test.tl`,
`action_ci_test.tl`, `action_queue_test.tl`, `converge_test.tl` and
`intake_test.tl`: they exercise the reader against legacy-shaped
sidecars, and changing them weakens that coverage.
