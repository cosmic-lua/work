Three files, four edits. Name `timestamp` in `RESULTS_SPEC` so it is
validated, print one `measured:` header line beneath #1485's
`binaries:` line, and document what the stamp actually means.

**1. `_perf/perf_types.tl` — document the field (no type change).**
Above `timestamp: number` (`:49`), add a doc comment saying the stamp
is UNIX epoch seconds, UTC, recorded when the results file is written
— that is, at the END of the run, after every scenario has been
measured. Do not change the declared type: `number` is what a decoded
JSON value is, and narrowing it to `integer` would make `load_results`
reject a file whose stamp round-tripped as a float (Evidence 5, probes
C and D).

**2. `_perf/compare.tl` — validate the field.** In `RESULTS_SPEC`
(`:38-48`), add to the `meta` record, beside `bin_sha`:

```teal
timestamp = shape.optional(shape.number),
```

`optional`, because a results file written before this field existed,
or by a run that could not stamp itself, must still load — the same
reasoning `bin_sha` already carries. `shape.number`, not
`shape.integer`: `integer` REFUSES a fractional value (Evidence 5,
probe C), and a stamp that round-tripped through an encoder as
`1756305221.0` would turn a loadable file into a refused one. The
whole-seconds guarantee comes from `time.now()` at the WRITE side
(Evidence 1), not from the read side, and the call site floors anyway.

Then edit the `RESULTS_SPEC` docstring's "fields ... left unnamed"
sentence (`:35-37`) so its list no longer implies `timestamp` is one of
them, and say in one clause why this one is named: it is read by
`format_measured` below, so a non-number would throw downstream.

**3. `_perf/compare.tl` — the header line.** Add
`local time = require("cosmic.time")` to the module's requires
(`:13-17`; the module does not require it yet), then add these two
file-local functions immediately above `format`'s docstring (`:281`),
below `format_identity` (`:268-279`). This is the exact code that was
type-checked under the pinned bootstrap and executed (Evidence 11) —
build it as written, and give each function a doc comment in the house
form (`---`, `@param`, `@return`):

```teal
local function format_gap(secs: integer): string
  local sign = secs < 0 and "-" or "+"
  local a = secs < 0 and -secs or secs
  if a < 60 then return string.format("%s%ds", sign, a) end
  if a < 3600 then return string.format("%s%dm", sign, a // 60) end
  return string.format("%s%dh%02dm", sign, a // 3600, (a % 3600) // 60)
end

local function format_measured(base: pt.Results, cur: pt.Results): string
  local bt = base.meta and base.meta.timestamp
  local ct = cur.meta and cur.meta.timestamp
  local bs: string | nil
  local cs: string | nil
  local bi: integer
  local ci: integer
  if bt ~= nil then
    bi = math.floor(bt)
    bs = time.format_iso8601(bi)
  end
  if ct ~= nil then
    ci = math.floor(ct)
    cs = time.format_iso8601(ci)
  end
  local gap = "(gap unknown)"
  if bs ~= nil and cs ~= nil then
    gap = "(current " .. format_gap(ci - bi) .. ")"
  end
  return string.format("measured: base %s  current %s  %s",
    bs or "unknown", cs or "unknown", gap)
end
```

What that code decides, stated so a reader does not have to infer it:

- `format_gap` renders a signed gap in the largest unit that still
  answers "same window or not", deliberately dropping finer precision
  above a minute: `+12s` under a minute, `+2m` (floored) under an hour,
  `+8h33m` (`%s%dh%02dm`, floored) above.
- Each side renders through `time.format_iso8601`, which is UTC with a
  `Z` suffix and exactly 20 characters (Evidence 12).
- A side renders as the word `unknown` when its `meta` is absent, its
  `meta.timestamp` is absent, or `format_iso8601` returns nil.
  `unknown` is the same word `format_identity` uses for an unnamed
  binary, for the same reason.
- The parenthetical is `(current <gap>)`, signed against the base to
  match the `base -> current` direction `format_delta` already reads
  in, and `(gap unknown)` when EITHER side is `unknown`.
- `bt`/`ct` use the `base.meta and base.meta.timestamp` idiom
  `format_identity` already uses at `_perf/compare.tl:269-270`; the
  `~= nil` guard on the plain local is what narrows it before
  `math.floor`.
- Both are file-local and are NOT added to the `local record compare`
  block or the `M` table. They are reached only through `format`, the
  tests drive them that way, and keeping the exported record unwidened
  is what keeps this diff off `_perf/skew_test.tl`'s signature surface.

In `format` (`:292-316`), inside the `if base and cur then` guard that
already exists, insert one line after the `format_identity` insert:

```teal
table.insert(lines, format_measured(base, cur))
```

so `format(deltas)` with no identity arguments still returns
byte-identical text to today's. Extend `format`'s docstring
(`:281-291`) with one sentence naming the second header line.

**If `_perf/compare.tl` would exceed 500 lines** (projection is ~464,
or ~481 behind #1486 — Evidence 10), move `format_gap` and
`format_measured` unchanged into a new `_perf/report.tl` required by
`compare.tl`, and Acceptance 7's file list becomes four. Do NOT trim
doc comments to fit, and do not move `format_identity`.

**4. `_perf/compare_test.tl` — exactly five new test functions**, each
a `test_*` called on the line after its `end` (AGENTS.md), each driving
`compare.format(deltas, base, cur)` over hand-built `pt.Results` values
(no measurement). The file already has the helpers: `results(...)`,
`m(name, wall_ns, spread_pct)` (`:4-16`) and `sha_results(sha)`
(`:297-300`); add a stamped variant beside `sha_results` rather than
inlining literals five times. Their names, so Acceptance 5's count is
unambiguous:

- `test_format_measured_line` — both stamps present, current later by
  30815 seconds → the report's SECOND line is exactly
  `measured: base 2026-08-27T05:50:12Z  current 2026-08-27T14:23:47Z  (current +8h33m)`.
- `test_format_measured_negative_gap` — current EARLIER than base by
  the same 30815 seconds → the parenthetical is `(current -8h33m)`.
- `test_format_measured_gap_units` — three assertions, one per
  `format_gap` branch, read off the rendered line: a 12-second gap →
  `(current +12s)`, a 150-second gap → `(current +2m)`, a 30815-second
  gap → `(current +8h33m)`. (Verified: `30815 // 3600 = 8`,
  `(30815 % 3600) // 60 = 33`; Evidence 11 printed all three.)
- `test_format_measured_unknown_side` — `cur.meta.timestamp` absent →
  the line is
  `measured: base 2026-08-27T05:50:12Z  current unknown  (gap unknown)`.
- `test_format_without_identity_unchanged` — `compare.format(deltas)`
  with no identity arguments returns text containing neither
  `measured: ` nor `binaries: `.

Note for the builder: the three existing `test_format_identity_*` tests
(`:301-337`) assert with `text:find(..., 1, true) == 1`, i.e. that the
`binaries:` line is FIRST. They keep passing — `sha_results` carries no
timestamp, so those reports simply gain
`measured: base unknown  current unknown  (gap unknown)` as line 2. Do
not edit them.
