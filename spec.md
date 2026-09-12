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

## Implemented and verified — 2026-09-12

Landed in [cosmopolitan PR #393](https://github.com/cosmic-lua/cosmopolitan/pull/393)
at `6c32f7a07cb7272300b2e06e06ac9db85360e024`; independent review accepted
the exact handover `49163af8e61961de865902f529e53bc0347bf670`.
The final change is 255 inserted lines across the new test, corpus and
explicit BUILD.mk enrollment. Existing tests and parser are unchanged.

PR run 34675442333 and merge-group run 34675803453 passed the Linux
x86-64 binding gate, aarch64/fat build and MODE=cov gate. Separate clean
Linux preflight 34676272246 passed the exact `make -j$(nproc)
o//tool/lua/test` aggregate and rel runtime build. Its coverage verdict:
69 tests traced, 4 existing shrink-only skips, 354/543 binding functions
covered; `test_coverage: PASS`. The new ASCII test was traced normally.

The 36,895 emitted records match byte-for-byte across repeated runs and
the Linux rel / pinned macOS runtimes. Corpus SHA256:
`e61139f10a9dbced988b9cd6721959a585db24d3e2d2efc18b5d60512d496048`.
Run from the C repository root: `RUNTIME tool/lua/test_ljson_ascii.lua --emit`.
Pinned macOS Cosmic SHA256 is
`10f66af3cfe6b55e3f97c058ddff5e6b0ba3faf6eef8c2462cb7372895e4e1c2`;
preflight Linux rel lua SHA256 is
`b28cb5dd07ea5d831d549dfb0301b095ce514c76f817ff68ed2cabeed0eca092`.
Exact build identity, commands and records are retained in the linked
[preflight artifacts](https://github.com/cosmic-lua/cosmic/actions/runs/34676272246)
and local `json-evidence/contract` / `json-evidence/preflight` artifacts.

Review caught low-bit LCG sampling that selected insertion every time.
The fixed generator exercises insert/delete/substitute/truncate
2,482/2,486/2,548/2,484 times. A permanent bounded diversity assertion
fails when the original low-bit selection is restored. Full corpus
generation stays in `--emit`; the normal assertion suite traces about
156,000 calls, below the unchanged 8,000,000-call per-test cap.
