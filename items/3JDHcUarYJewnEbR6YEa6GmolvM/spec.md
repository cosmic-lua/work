## Change

Implement ONLY the bounded ASCII prefix/direct-string path described by
parent Ev3f_N6gu's Fixed algorithm in `tool/net/ljson.c:323`. The nested
compatibility and benchmark children must be complete, with an unmodified
local baseline saved. Do not change definitions.lua or the Unicode/escape
fallback switch, including its existing ASCII arm.

## Access

cosmic-lua/cosmopolitan (master), cosmic-lua/cosmic (fixed benchmark tree),
cosmic-lua/work.

## Implementation

Add one pointer for the prefix start. After the existing context refusal,
scan using p<e before kJsonStr[(unsigned char)*p]. At a quote, push the
bounded string and return exactly one Lua value with r.p=p+1. At any other
byte or e, initialize b, append the nonempty prefix once, and fall into
the unmodified loop at that same p. No buffer cleanup label may run with
b uninitialized. Do not reuse the number parser's a variable, pre-read
beyond e, consume exceptional bytes, or retain borrowed input pointers.
Keep the diff surgical, expected <50 production lines. No helper library,
thresholds, SIMD, allocations outside Lua, allocator hook, or C API change.

## Verification

Run full Lua binding tests including the new contract matrix on Linux.
Build baseline and candidate from clean output directories with the same
toolchain/mode; compare the full deterministic corpus records, including
return counts/errors. Inspect all DecodeJson/DecodeJsonEx callers for
explicit-length safety and review both bound checks. Run repeated success/
failure with forced GC; use existing sanitizer facilities where available.
If a baseline bug is exposed, record it separately instead of repairing it.

Build cosmic twice on these local runtimes with IDENTICAL cosmic source
and harness files; require build: PASS, record binary hashes, and run
candidate --make ci plus full performance compare. Require parent target/
fallback acceptance, not just a microbenchmark improvement. Confirm on
rel-versus-rel before landing. A tiny effect follows the skill's noise
discipline; a surviving regression or absent target gain rejects the
change. Do not await the final child to discover whether the C change is
safe to merge. Record exact corpus commands, diff count zero, full test
verdicts and performance rows on this item before landing/release.

## Executed C verification

Exact candidate ac5d2d8cf7ae14bf6ffce30f255c495fee597964 changes only
tool/net/ljson.c, 10 additions and 1 deletion, against the landed test-only
baseline 6c32f7a07cb7272300b2e06e06ac9db85360e024. Both assembled subjects
use identical Cosmic 3b022027e1a69b6274a10fe13b866fdeecad5df3. The frozen
fallback switch and public definitions remain unchanged. Builder and
independent reviewer both audited all four external call sites and both
new bound checks, Lua result ownership, stack shape, and buffer cleanup.

[Linux run 34678285918](https://github.com/cosmic-lua/cosmic/actions/runs/34678285918)
built each C source from a clean directory, sequentially at the same
absolute path, with cosmocc 2025.12.30-0c0b4c8c8 on Linux x86_64,
kernel 6.17.0-1022-azure, four CPUs, pinned Noble container
sha256:cfb30ff3856780c63b00ec3ad2e4aed77ae6afce5975ebb8ad9525ec45354e2e.

Both `make -j$(nproc) o//tool/lua/test` and
`make -j$(nproc) m=rel o/rel/tool/lua/lua` succeeded. Both binding gates
include the new matrix, existing JSONTestSuite, and `test_coverage: PASS`.
Running each saved rel runtime from its C source root with
`tool/lua/test_ljson_ascii.lua --emit` produced 36,895 records. `cmp`
reported zero differences. A separate candidate `m=dbg` build uses
`-fsanitize=undefined`; the old JSON assertions, new matrix, GC probe,
and full emitted corpus all passed. Its 36,895 records also match exactly.
All three record files hash to
e61139f10a9dbced988b9cd6721959a585db24d3e2d2efc18b5d60512d496048.

The same saved dynamic GC probe ran on both rel runtimes and candidate
UBSan: `json-gc-stress: PASS iterations=128 held=8`. It drops generated
64 KiB inputs before full collection, independently reconstructs expected
bytes, retains eight older results across subsequent parses/collections,
and checks escaped/UTF-8 fallback and five exact failure tuples. Probe
SHA256 e5090497758b83071946fb1520ea9a4bbc25f268d00aa9eb054259ad59274e8b.

The compiled mutation changed only the fast return from p+1 to p.
Compilation/relink succeeded; the matrix exited 1 at its success assertion
(line 65, invoked at 79). The source was restored exactly, rebuilt, and
the same assertions passed. The saved rel binary hash remained unchanged.

Verified binary SHA256 identities:

| Subject | SHA256 |
|---|---|
| Baseline local rel Lua | b28cb5dd07ea5d831d549dfb0301b095ce514c76f817ff68ed2cabeed0eca092 |
| Candidate local rel Lua | 29f931e519c6afff8d4a97c86d29807f1a38acdb9b2bc94956c56e69127aeea6 |
| Baseline assembled Cosmic | 38a9c619b54399bfe6265cd851d50ca16602cbcceae855101f2904893895f14a |
| Candidate assembled Cosmic | cd5f78e96c34dd5fa70aab4f852f8034a8d3f586e4032c71aebc5628dc82aa09 |

Both assembled builds reported `build: PASS (692 files, 1 binary)`.
The first Cosmic CI run passed 3548/3549 tests but failed its assimilation
fixture: temporary global APE binfmt registration bypassed the shell
trampoline implementing --assimilate. Source inspection confirmed the
cause; normal Cosmic CI does not register binfmt. The corrected downstream
run retains these exact hashed C artifacts, reproduces both Cosmic
binaries, and reruns full CI and performance without changing any test.

## Corrected downstream result and performance

[Run 34679751184](https://github.com/cosmic-lua/cosmic/actions/runs/34679751184)
completed successfully. It independently verified the saved C evidence,
rebuilt both Cosmic subjects at the original absolute path, and reproduced
both SHA256 identities above exactly. The full candidate gate reported
3549 tests passed, `coverage: PASS (318 files)`, and `ci: PASS (5 stages)`.
The assimilation fixture passed with ordinary shell APE handling.

On that Linux x86_64 runner, four adjacent A/B JSON pairs measured long
ASCII at 96.714/25.621, 97.521/25.651, 97.690/25.566, and 98.215/25.643
microseconds (baseline/candidate): all four improved. A fresh full-suite
comparison gave the following medians; parentheses are within-run spreads.

| Scenario | Baseline us (spread) | Candidate us (spread) | Time delta |
|---|---:|---:|---:|
| json_decode_small | 1.091884 (2.50%) | 0.803484 (3.43%) | -26.4% |
| json_decode_large | 855.217291 (2.88%) | 631.964891 (0.89%) | -26.1% |
| json_encode_large | 1026.059000 (3.51%) | 1057.101216 (0.51%) | +3.0%, within noise |
| json_roundtrip_small | 2.484337 (0.56%) | 2.205277 (0.23%) | -11.2% |
| json_decode_ascii_long | 97.888941 (2.19%) | 25.998567 (0.79%) | -73.4% |
| json_decode_ascii_short | 24.629095 (0.63%) | 14.158363 (1.25%) | -42.5% |
| json_decode_ascii_escaped | 120.177742 (0.21%) | 52.447800 (0.19%) | -56.4% |
| json_decode_ascii_utf8 | 39.281130 (1.39%) | 21.273384 (1.94%) | -45.8% |

Both arms used the same exact Cosmic source and checked harness, explicit
hashed subject binaries, default five samples and 0.15-second minimum.
Commands used `--make run _perf/baserun.tl --bin SUBJECT --out FILE`
(with `--only json _perf.bench.json_bench _perf.bench.json_string_bench`
for adjacent pairs), candidate `--make run _perf/run.tl --out current.json`,
then `env -u PERF_BIN ... --make run _perf/gate.tl compare baseline.json
current.json selfcheck-b.json --baseline-bin BASELINE_BINARY`.
Baseline, current, and self-check paths were distinct. The plain compare
exited 0. The full gate exited 0 and reported `perf-compare: PASS`:
53 scenarios, 0 regressions, 8 faster, 45 ok, 0 noise, no missing or error
rows. Long ASCII clears the noise bar; common short strings, large JSON,
and both fallbacks improve. No workload, threshold, or check was changed.

[C PR394](https://github.com/cosmic-lua/cosmopolitan/pull/394) has also passed
its exact-head required [CI run34679328728](https://github.com/cosmic-lua/cosmopolitan/actions/runs/34679328728),
including MODE=cov. Independent final review and normal protected landing
follow; the final child still verifies the actual released package.

Final independent review accepted ac5d2d8cf7ae14bf6ffce30f255c495fee597964,
including byte equality of all 809 embedded Cosmic payload members.
PR394 landed through the protected queue at
780f45055acd52401de6c95c16365338690e19e7 on 2026-09-12T13:29:32Z.
[Merge-group CI34696132469](https://github.com/cosmic-lua/cosmopolitan/actions/runs/34696132469)
passed all architecture, sandbox and coverage checks. This chunk is complete.
