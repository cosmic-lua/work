## Change

Add `_perf/bench/json_string_bench.tl` with checked cosmic.json.decode
workloads for the proposed ASCII-string path, preserving every existing
scenario in json_bench.tl. Land this benchmark before the C optimization
so identical workload/check code runs on both sides of the comparison.

## Access

cosmic-lua/cosmic (main), cosmic-lua/cosmopolitan (baseline local runtime),
cosmic-lua/work. The nested compatibility-test child must be complete;
parent Ev3f_N6gu contains measurement and release requirements.

## Implementation

Use cosmic.json only for measured decode calls and the existing perf_types
Scenario/BenchModule structure. Construct input and exact expected values
once outside fn; fn returns decoded result, check compares full bytes and
shape, never just length or a single sampled element.

- json_decode_ascii_long: a quoted 64KiB deterministic repeating printable
  ASCII alphabet excluding quote/backslash; include raw DEL in the pattern.
- json_decode_ascii_short: an array of 256 strings, lengths cycling
  0..31, with all nonempty strings distinct (the eight empty strings
  necessarily repeat), and exact expected order and contents. This tests common short
  strings and avoids an all-identical-string interning-only workload.
- json_decode_ascii_escaped: array of 64 strings, each 1024 ASCII prefix
  bytes followed by escaped newline, quote and backslash and a short suffix;
  exact decoded bytes known independently of json.decode.
- json_decode_ascii_utf8: array of 64 strings with ASCII prefixes cycling
  0,8,64,1024 bytes, valid two/three/four-byte UTF-8 and an ASCII suffix.
  Ensure the high byte is the first byte after the prefix. Exact bytes
  must round-trip; this is a fallback cost sentinel.

Build valid quoted inputs explicitly from known fragments rather than
using json.encode to accidentally escape DEL/non-ASCII or alter the
intended workload. No raw cosmo calls, filesystem/network fixture, new
public type, nil cast, or extra dependency. Auto-discovery should find
the new *_bench.tl; confirm via the harness and smoke test. File <500
lines, target <=200 lines.

## Verification

Run `_perf/perf_test.tl` and the new scenarios via an explicit built binary
and --make run. Demonstrate full checks reject a same-length wrong byte
and reordered array in a focused test, without leaving corruption in the
scenario. Save a full baseline plus A/A control with hashes, source refs,
flags and host after this commit, using the unmodified local C runtime.
No performance assertion is made by this test-only/benchmark PR.

## Implemented and verified — 2026-09-12

Landed in [cosmic PR #1836](https://github.com/cosmic-lua/cosmic/pull/1836)
at `c9cdb84211b00239dfc88d3331fe2785d33800a0`; independent review accepted
handover `3b022027e1a69b6274a10fe13b866fdeecad5df3`. The sole change is
the 125-line benchmark module. Existing scenarios are unchanged.

Independent byte probes confirmed 65,536 long-string bytes including
697 raw DEL bytes; 256 short strings with eight empty and 248 distinct
nonempty values; 64 escaped strings with 1,024-byte prefixes; and 64 UTF-8
strings with the specified prefix lengths. Source mutations causing
same-length wrong bytes and a rotated array both failed the checks.
Restored sources, clean checkout, focused run and types/fmt/lint passed.

[PR Linux run 34676804398](https://github.com/cosmic-lua/cosmic/actions/runs/34676804398)
passed ci, build, reproducibility, macOS smoke and Windows smoke.
The local macOS full gate had unrelated process/network/PTY/timestamp
capability failures; no exemption or weakened check was introduced.

Before any C edit, [baseline run 34676805738](https://github.com/cosmic-lua/cosmic/actions/runs/34676805738)
built the landed unmodified C source `6c32f7a07cb7272300b2e06e06ac9db85360e024`
from clean outputs, passed `make -j$(nproc) o//tool/lua/test`, built rel,
assembled exact Cosmic source `3b022027e1a69b6274a10fe13b866fdeecad5df3`,
ran all 53 scenarios, and saved separate baseline/A/A files. The raw corpus
still matches SHA256 `e61139f10a9dbced988b9cd6721959a585db24d3e2d2efc18b5d60512d496048`.
Host: Linux x86-64, kernel 6.17.0-1022-azure, four logical processors,
pinned noble container digest `cfb30ff3856780c63b00ec3ad2e4aed77ae6afce5975ebb8ad9525ec45354e2e`.

| Scenario | Baseline median µs | A/A first µs | A/A second µs |
| --- | ---: | ---: | ---: |
| json_decode_large | 729.387 | 689.125 | 729.085 |
| json_decode_ascii_long | 76.221 | 76.934 | 77.173 |
| json_decode_ascii_short | 18.998 | 19.331 | 19.395 |
| json_decode_ascii_escaped | 93.860 | 93.558 | 97.352 |
| json_decode_ascii_utf8 | 30.635 | 30.578 | 35.958 |

The full A/A run exposed natural variation, including UTF-8; these are
pre-edit measurements, not optimization gains. Candidate acceptance must
remeasure both runtimes in one session and use the unchanged noise gate.
Raw rel runtime SHA256:
`b28cb5dd07ea5d831d549dfb0301b095ce514c76f817ff68ed2cabeed0eca092`.
Assembled baseline Cosmic SHA256:
`38a9c619b54399bfe6265cd851d50ca16602cbcceae855101f2904893895f14a`.
Exact commands, build logs, hashes, all readings and spreads are in the
run artifacts and local `json-evidence/benchmark-baseline`.
