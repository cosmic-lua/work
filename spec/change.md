Touch exactly two files: `cosmic/time.tl` and `cosmic/time_test.tl`.

In `cosmic/time.tl`, at each of the five `unix.clock_gettime` call sites
(lines 34, 43, 52, 60, 70 today — the bodies of `now`, `monotonic`,
`now_ms`, `monotonic_ms`, `monotonic_ns`), bind slot 1 through `assert`
so the local is a plain `integer` and the declared returns stop lying.
Rename only the raw binding, so the asserted local keeps the name the
rest of the body already uses:

```teal
local secs_or_nil, nanos = unix.clock_gettime(unix.CLOCK_REALTIME)
-- assert: clock_gettime fails only on an invalid clock id, and
-- cosmopolitan guarantees CLOCK_REALTIME never raises EINVAL
local secs = assert(secs_or_nil, "clock_gettime(CLOCK_REALTIME) failed")
```

and the `CLOCK_MONOTONIC` equivalent at the three monotonic sites. Every
site gets its own `-- assert:` comment naming its clock, because D23's
rule is per-assert; the FIRST site (`now`) carries the fuller form above
(binding contract plus the guarantee), the other four may carry the
one-line form (`-- assert: cosmopolitan guarantees CLOCK_MONOTONIC never
raises EINVAL; clock_gettime fails only on an invalid clock id`).

The five functions' signatures and their `---` doc comments do NOT
change — that is the point of the shape chosen. No caller changes.

In `cosmic/time_test.tl` (353 lines today), add one test beside the
existing `test_now` / `test_monotonic` asserting that each of the five
public readers returns a non-nil integer and that a monotonic pair does
not go backwards — the failure path is unreachable through the public
API, so the test pins that the asserted values reach callers, not a
forced failure. Call it on the line after its `end`, per AGENTS.md.
