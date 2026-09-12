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
