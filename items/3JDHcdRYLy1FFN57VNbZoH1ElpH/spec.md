## Change

Add `tool/lua/test_ljson_ascii.lua` to freeze the current decoder's string
behavior and add a deterministic differential corpus driver under
`tool/lua/testdata/json_ascii_corpus.lua`. Wire the new test into
`tool/lua/BUILD.mk` using the existing test_ljson test recipe and aggregate
test dependencies. This is a test-only PR; leave ljson.c unchanged.

## Access

cosmic-lua/cosmopolitan (master), cosmic-lua/cosmic (optimize skill),
cosmic-lua/work. Parent Ev3f_N6gu supplies the algorithm and full test matrix.

## Implementation

Implement the parent's Test specification as executable assertions that
pass against the unmodified runtime. Use exact old behavior for control,
Unicode and extension cases, not an external JSON parser's defaults.
Keep existing test_ljson.lua/JSONTestSuite unchanged. Inspect BUILD.mk's
explicit .ok dependencies; creating a test file alone is not enrollment.
Follow existing Lua binding test conventions, not cosmic's Teal runner.

The shared corpus module returns case id, input bytes and wrapper context;
it includes the parent's exhaustive byte/prefix matrix and 10,000 seeded
mutations of quoted strings (fixed seed 0x4a534f4e, locally implemented
32-bit LCG `state = (1664525 * state + 1013904223) % 2^32`, no global
randomseed). Operations insert,
delete, substitute or truncate bytes. Cap each fuzz input at 4096 bytes;
the fixed long-string cases separately reach 65536. A driver mode emits
one tab-separated case-id plus typed fingerprint per case using hex for
all arbitrary bytes, including errors. Fingerprint table entries in a
stable order, distinguish array marker/null sentinel and return arity.
No wall-time budget controls case selection. Baseline and candidate must
emit identical records for the identical corpus; report the first differing
case's full input hex. Use `RUNTIME tool/lua/test_ljson_ascii.lua --emit`
from the repository root for fingerprints; without --emit run assertions.
The corpus module loads by an explicit repository-relative Lua path;
include it as a prerequisite of the new .ok target so changes rerun tests.

Use a bounded golden set of specifically enumerated cases for permanent
test assertions; differential comparison is run against two separately
built runtimes during the implementation child. Do not persist an entire
copied old decoder or thousands of generated expected-output rows.
No annotations, API/type changes, casts, or unrelated parser fixes.

## Verification

Run the new tests and complete `make -j$(nproc) o//tool/lua/test` on Linux.
Prove the new .ok target is included in that aggregate. Save baseline
corpus fingerprints with runtime SHA/source SHA and exact command. The
baseline test run must pass before the C fast path is attempted. Aim for
<=350 changed lines across test, shared corpus/driver and BUILD.mk; use
small helpers rather than growing the existing test file indefinitely.
