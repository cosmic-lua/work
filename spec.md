## Change

Restore a reliable 50,000-iteration scheduled fuzz lane after the repository's
bounded test runner made the existing compression and tar properties exceed
their per-file deadline. Repo `cosmic-lua/cosmic`. Diagnose and reduce the
properties' work or split their independently useful properties so the lane
passes under the existing 120-second bound with margin. Preserve
`FUZZ_ITERS=50000`, property semantics, failure visibility, the workflow's
30-minute job limit, and the runner's default file deadline. Do not solve this
by raising a timeout, lowering iterations, weakening generated input sizes,
removing formats or hostile tar cases, serializing the whole suite, or adding
`continue-on-error`.

Measure compression's three properties and tar's three properties separately
on the pinned Linux runner with at least three recorded seeds. Attribute time
to generation, compression/decompression or filesystem extraction rather than
using total wall time alone. Check whether per-property test files can preserve
fresh-process isolation while allowing the runner to bound each property
independently; compare that with reducing setup and filesystem churn without
reducing fuzz coverage. Keep parallel runner contention in the measurement:
an isolated fast file is insufficient if the real `_fuzz` lane still misses
its deadline.

Verification: the unchanged workflow command completes at
`FUZZ_ITERS=50000` for three recorded seeds, including `20260912`, with every
property assertion executed and at least 15% headroom below 120 seconds for
each file. The normal `_fuzz` gate, coverage, types, format, lint, full Linux
CI, and pull-request fuzz lane pass. Add a regression that proves every split
property remains enrolled once and receives the requested iteration count.
Mutation checks must show that removing one property or silently reducing its
iterations fails. Record per-property timings and reproduce commands in the
PR; do not claim a product runtime speedup unless separately measured.

## Evidence

The 120-second default entered in commit `739032d2` (#1811). Scheduled deep
fuzz succeeded before that bound while individual files took longer: run
34357842321 recorded compression 140.398 seconds and tar 139.692 seconds at
seed `20260909`; run 34231704412 recorded compression 139.650 seconds and tar
109.702 seconds at seed `20260908`; run 33760762223 recorded compression
131.756 seconds and tar 134.327 seconds at seed `20260903`. The next three
scheduled runs were red.

Exact candidate `f5880979` reproduced the issue without changing either
property. Run 34720009857 at seed `20260912` passed all 86 fuzz assertions;
compression timed out at 120.010 seconds while tar passed in 113.638 seconds.
Run 34720614042 at workload-selected seed `447723523` passed compression in
103.051 seconds and all 86 assertions before tar timed out at 120.010 seconds.
Retry 34720960148 showed runner contention: both files timed out at 120.010
seconds, while all 83 completed assertions and every new diagnostic suite
passed. Local macOS at seed `20260912` showed the inverse edge once:
compression passed in 101.24 seconds while tar reached the same deadline.

This follow-up is separate from fuzz diagnostic correctness. It must not alter
checkpoint, observation, signal classification or diagnostic report behavior.
