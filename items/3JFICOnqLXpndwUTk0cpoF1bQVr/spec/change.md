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
