`_perf/bench/literal_bench.tl` only:

1. A map-view reference `format_any` (casts justified, #1415's
   pattern) typed `function(any, any?): any`, used by the compact
   scenario's `fn` and by a `supports_compact()` probe: format a tiny
   probe table both ways; compact is supported iff the outputs
   differ (the old format ignores the opts and produces the pin
   layout twice).
2. `scenarios()` builds the list without the compact scenario and
   inserts it at its original position (3rd, keeping the
   floor-first heap ordering the header explains) only when
   `supports_compact()` is true.
3. The header comment gains the constraint (bare under older
   binaries; silent-pin hazard; register-on-support).
