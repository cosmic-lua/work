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
