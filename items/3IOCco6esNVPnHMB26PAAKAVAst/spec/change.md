Two new files, one added test in an existing one, and the two committed
floors those regenerate. Nothing else in the tree moves.

### `cosmic/test.tl` — new, public

A `---` doc comment header whose first line is the module's one-line
description; that line is what `cosmic --docs` indexes and what
`cosmic/surface_test.tl` requires. The header also records, the way
`cosmic/check.tl:14` does for `EXIT_SKIP`, that the two output spellings
below are `_tool/records.tl`'s and are reproduced rather than imported
because `cosmic/**` may not require the internal tree.

The exported surface is two types and one function:

```teal
local record Case
  name: string
  fn: function()
end

local record Options
  --- A plain SUBSTRING matched against a case name — the benchmark and
  --- example runners' contract, not a Lua pattern. When absent,
  --- COSMIC_TEST_FILTER is read instead.
  filter: string
end

main: function(cases: {Case}, opts?: Options): integer
```

`main` does exactly this, in order:

1. Resolve the filter: `opts.filter` when it is a non-empty string, else
   `require("cosmic.env").get("COSMIC_TEST_FILTER")` when that is a
   non-empty string, else no filter.
2. Select cases **in the order given** — source order; never sorted,
   never shuffled. With a filter, keep the cases satisfying
   `name:find(filter, 1, true)`; the literal `1, true` is what the
   `find-needle` lint requires and the substring contract is what it
   means here.
3. If no case is selected, write the skip output below and return `2`.
4. Otherwise run each selected case under
   `xpcall(case.fn, handler)`, where `handler` is
   `function(e: any): string return debug.traceback(tostring(e), 2) end`.
   A throw records that string against the case's name and the loop
   **continues to the next case**. Nothing aborts the run.
5. Write the output below and return `0` when every selected case passed,
   `1` when any failed.

`main` writes with `io.write` to stdout and never calls `print`, so a
caller can capture all of its output by swapping `io.write` alone. It
never calls `os.exit` and never throws: it is an ordinary `cosmic.*`
library function that returns a value, which is what D23 requires of
every `cosmic.*` module but `cosmic.check`.

The output, exactly:

- One block per FAILING case, in run order, before the summary: the line
  `✗ <name>`, then the recorded traceback string with each of its lines
  indented four spaces.
- Then, always, the counts line followed by a newline:
  `<N> checks: <P> passed[, <F> failed]`, where `N` is the number of
  cases RUN. The skipped count is always 0 in this slice — there is no
  per-test skip (D29 keeps `check.needs`/`check.reap` exiting the
  process) — so the `, <S> skipped` arm never appears.
- When a filter selected nothing while `cases` is non-empty, one line
  before the counts line:
  `no tests matching '<filter>' (found <N> total)`. When `cases` itself
  is empty, nothing before it. Either way the counts line is
  `0 checks: 0 passed` and the return value is `2`.

### `cosmic/test_test.tl` — new

Legacy mode: every `test_*` self-called on the line after its `end`, as
the whole tree still is. Uses `cosmic.check`. A local helper wraps a
`main` call, swapping `io.write` for a collector and restoring it on both
the normal and the throwing path, and returns the exit code with the
captured text. The tests:

- `test_every_case_runs_past_a_failure` — three cases, the middle one
  throwing: the third case's side effect happened, the return is `1`, and
  the output names the middle case.
- `test_all_passing_returns_zero` — two passing cases: return `0`, last
  output line `2 checks: 2 passed`.
- `test_failure_output_names_the_function_and_carries_a_traceback` — one
  throwing case: the output contains `✗ <name>` and, indented below it,
  the thrown message and a `stack traceback:` whose frames name this
  file. (They name the COMPILED chunk, `o/cosmic/test_test.lua`, since a
  test runs as the chunk the build produced — measured at pull.)
- `test_source_order_is_run_order` — each case appends its name to a
  list; the list equals the input order.
- `test_empty_case_list_is_a_skip` — `main({})` returns `2` and writes
  `0 checks: 0 passed`.
- `test_filter_selects_by_substring` — three cases and
  `{filter = "beta"}`: only the matching case ran, return `0`, counts
  line `1 checks: 1 passed`.
- `test_filter_matching_nothing_is_a_skip` — return `2`, and the output
  names the filter and the total.
- `test_the_env_var_is_the_filter_when_no_option_is_passed` — `env.set`
  around the call and `env.unset` after, asserting the same narrowing;
  and that an empty-string value is treated as no filter at all.
- `test_a_failing_case_does_not_leak_io_write` — after a `main` call
  whose case throws, `io.write` is the real one again.

### `_tool/records_test.tl` — one added test

`test_the_public_runner_and_the_records_grammar_agree`: capture
`require("cosmic.test").main` over one passing and one failing case, and
assert the summary line is byte-identical to `records.counts(1, 1, 0)`
and the failure line to `records.row("fail", <name>, 0, "")`. This is the
drift guard the reproduced grammar needs, in the file that already guards
`check.EXIT_SKIP` against `records.EXIT_SKIP` at `:130`.

### `cosmic/test_example.tl` — new

The `*_example.tl` a public module owes (`cosmic/example_coverage_test.tl`,
whose waiver list is closed). Two `Example_*` functions, each with a
`-- Output:` block so the example runner compares real output:
`Example_main` runs two passing cases and prints the exit code;
`Example_filter` shows the substring narrowing and the
nothing-matched skip. Bodies are extracted and recompiled, so each
`require` lives inside its function.

### `_cli/env_vars.tl` — one added row

`COSMIC_TEST_FILTER`, `public = true`, described as the runner's name
filter. `_build/env_vars_test.tl` fails a `COSMIC_*` name that code reads
and the registry does not declare, and `--help` renders the public rows.

### The two committed floors

Regenerate and commit both, with the commands the gates print — in
scope, and the only sanctioned way to move either:

- `bin/cosmic --make run _build/public_surface.tl --baseline` →
  `_build/public_surface_baseline.tl` gains `["cosmic.test"] = true`.
- `bin/cosmic --make coverage --baseline` → `.cosmic-coverage` gains rows
  for the two new files.
