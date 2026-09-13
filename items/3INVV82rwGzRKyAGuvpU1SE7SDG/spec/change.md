Two files.

**1. `_perf/bench/literal_bench.tl`** (new) — a bench module in the
shape of `_perf/bench/format_bench.tl`: a module header saying what it
measures and why, inputs built once at load, a `scenarios()` returning
`{pt.Scenario}`, an empty `cleanup()`, and a `pt.BenchModule` returned
at the end.

Build two values in memory, deterministically, at module load:

- `PIN`, a table with the shape and rough size of a `*_pin.tl`: a
  `format`/`url`/`version`/`strip_components` set plus a nested
  `platforms` table of a few entries with `sha` strings. Aim for the
  few-hundred-byte range `3p/cosmos/cosmos_pin.tl` sits in.
- `FLOOR`, a table of 251 keys — `"path/to/file" .. i .. ".tl"` — each
  mapping to `{covered = <int>, total = <int>}`, the shape
  `.cosmic-coverage` carries at the size it carries it.

Beside each, its formatted source, produced once at load with
`literal.format` (the pin layout), so the parse scenarios time parsing
and not formatting.

Four scenarios, named exactly:

- `literal_parse_pin` — `literal.parse(PIN_SOURCE)`
- `literal_parse_floor` — `literal.parse(FLOOR_SOURCE)`
- `literal_format_pin` — `literal.format(PIN)`
- `literal_format_floor` — `literal.format(FLOOR)`

Every scenario defines `check` — the harness requires one, and a
missing one fails `_perf/perf_test.tl`. Make each check discriminate a
faster-but-wrong implementation rather than merely testing for
non-nil:

- a parse check narrows the result to `{string: any}`, then asserts a
  known scalar reached it (the pin's `version` string; a named floor
  row's `covered`) AND that the table has the expected number of
  top-level keys, counted with `pairs`. A reader that dropped entries
  would be faster and would fail here.
- a format check narrows the result to a string, parses it back with
  `literal.parse`, and asserts the round trip equals the value it was
  given on the same two probes plus the key count. A writer that
  skipped entries would be faster and would fail here.

Follow the repo's error shape: a check returns `boolean, string`, and
its failure message names the scenario and what it saw.

**2. `_perf/perf_test.tl`** — in the header comment at `:11`, change
`the 17 bench sources` to `the 18 bench sources`. That is the whole
edit to this file; the module list itself is derived and needs none.
