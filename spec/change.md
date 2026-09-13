**The binary identity is a property of a results FILE, not of a row.**
Every row in one report comes from the same pair of files, so the
identity is printed ONCE, as a header line above the rows — not as a
per-row column, which the width measurement above rules out.

1. **`_perf/compare.tl`** — add

   ```teal
   local function format_identity(base: pt.Results, cur: pt.Results): string
   ```

   returning one line, using the same 12-hex prefix
   `identity_refusal` already uses (`string.sub(sha, 1, 12)`,
   `_perf/compare.tl:319`) so the two agree on sight:

   ```
   binaries: base 145057b9fe90  current 145057b9fe90  (same)
   binaries: base 145057b9fe90  current 9f2c1ab30de4  (differ)
   binaries: base 145057b9fe90  current unknown  (unverifiable)
   ```

   `unknown` is the word for a side whose `meta.bin_sha` is absent, and
   `(unverifiable)` the verdict when either side is unknown — never
   `(same)`, which would assert what the file does not say. Export it
   beside `format_delta`.

2. **`_perf/compare.tl`** — widen `format` to

   ```teal
   local function format(deltas: {pt.Delta}, base?: pt.Results, cur?: pt.Results): string
   ```

   prepending `format_identity(base, cur)` when BOTH are non-nil, and
   emitting exactly today's text when either is nil. Optional
   parameters, so no existing caller or test has to change to keep
   working. Update the exported record type to match.

3. **`_perf/gate.tl`** — add a file-local

   ```teal
   local function print_report(base_path: string, cur_path: string, deltas: {pt.Delta})
   ```

   which loads both paths with `compare.load_results` and prints
   `compare.format(deltas, base, cur)` (a `| nil` from a failed load
   flows into the optional parameter and drops the header — a file
   that will not load is the next call's error to report, in its own
   words, exactly as the existing local `identity_refusal` already
   reasons at `_perf/gate.tl:107-110`). Replace all four
   `print(compare.format(deltas))` with `print_report(...)` over the
   pair each site just compared, named in Evidence.

4. **`_perf/run.tl:358`** — `print(compare.format(deltas, base, cur))`.
   Both locals are already in scope and already narrowed.

5. **`_perf/compare_test.tl`** — four cases: the header's three states
   (`same`, `differ`, `unverifiable` with one side absent), and that
   `format(deltas)` with no identity arguments is byte-identical to
   what it returns today.
