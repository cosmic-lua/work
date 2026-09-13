Two files change, both under `_tool/`.

**1. `_tool/records.tl` — the parser and the new line, beside their
inverses.** This module is already the one home of the output grammar and
already carries `parse_counts` as the inverse of `counts`; the child's
per-test output is the same kind of thing, so it is parsed here and not in
the runner. Measured now: `wc -l < _tool/records.tl` is 309, 191 lines of
headroom under the 500-line cap.

Add two functions and their entries in `RecordsModule` / `M`:

- `parse_cases(names: {string}, out: string): {Status} | nil, string` —
  attribute one `Status` per name, in the order given, from a child's
  stdout. It is pure: no fs, no cwd. The rules, exactly:
  1. The **last non-empty line** of `out` must match `^%d+ checks: `.
     If it does not, return `nil, "no trailing counts line"`. This is the
     legacy/runner discriminator and the reason no mode check is needed:
     `cosmic/test.tl:157` writes the counts line last and the seam's tail
     is `os.exit(...)`, so a runner-mode child always ends on it, and a
     legacy-mode child (a plain script) never does.
  2. Parse that ONE line with `parse_counts`. Require `c.skipped == 0` —
     `cosmic.test`'s `counts` (`cosmic/test.tl:102-108`) has no skipped
     clause, so a nonzero one means the line came from somewhere else.
  3. A name is `"fail"` when a line of `out` is EXACTLY
     `ICONS.fail .. " " .. name` for a name in `names`. Membership-gated
     on purpose: `report()` prints rows with the same icon, and a test
     that calls `testrun.report` writes them to its own stdout
     (`_tool/testrun_test.tl:164,177,190,213,227,237` do exactly this) —
     but those rows name FILE paths, never `test_*` names, so the gate
     excludes them. `cosmic/test.tl:153` indents every traceback line four
     spaces, so a traceback can never match either.
  4. Require `c.passed + c.failed == #names` and
     `c.failed == <number of names matched in step 3>`; otherwise return
     `nil, "counts do not account for the cases"`. This is what makes a
     filtered run, a mid-run `os.exit`, and a crash fall back rather than
     invent statuses.
  5. Return `{Status}` — `"fail"` for a matched name, `"pass"` for the
     rest — in the order of `names`.
- `test_counts(passed: integer, failed: integer): string` — the line
  `N tests: P passed[, F failed]`, without its newline. Deliberately
  spelled `tests:` and not `checks:`, and deliberately carrying NO
  `skipped` clause: see the Non-goals wall on `parse_counts`.

**2. `_tool/testrun.tl` — write statuses, and total by test.** Measured
now: `wc -l < _tool/testrun.tl` is 337, 163 lines of headroom.

- In `run()`, at the existing `.tests` write (`_tool/testrun.tl:159-177`):
  keep the source scan for `^local function (test_[%w_]+)` exactly as it
  is, keep the `#test_names > 0` guard, and keep writing only for the
  `test` and `coverage` stages. After building `test_names`, call
  `records.parse_cases(test_names, stdout_content)`. When it returns a
  status list, write one `name .. "\t" .. status` line per name; when it
  returns nil, write today's bytes unchanged (`name` per line). Keep the
  write best-effort — a failure warns on stderr and does not fail the run.
- In `report()`, where `.tests` is read (`_tool/testrun.tl:245-252`):
  keep `test_count` as the count of LINES (the row annotation must not
  move). Additionally, per line, match `^([^\t]+)\t(%S+)$`; a line that
  matches contributes to `tests_passed` / `tests_failed`, and a `fail`
  contributes its name to that result's failing-test list. Carry the
  failing names on `TestResult` as a new `failing_tests: {string}` field
  (`{}` when none) — a record field, not a third return.
- Print `records.test_counts(tests_passed, tests_failed)` on its own line
  **after** the existing `records.counts(...)` line and **before** the
  `wall:` line, and ONLY when `tests_passed + tests_failed > 0`. Zero
  statused rows means no line, which is the whole tree today (see the
  runner-mode measurement below), so `--make ci` output does not move.
- In the `Failures:` block (`_tool/testrun.tl:302-322`), for a failing
  result whose `failing_tests` is non-empty, print before the `stderr:`
  block:

  ```
    failing tests:
      test_trim
      test_split
  ```

  (two-space `failing tests:`, four-space names, source order.)

Nothing in this slice runs in the tree today: measured, **0 of 276
`*_test.tl` files are in runner mode** —

```
for f in $(find . -name '*_test.tl' -not -path './o/*'); do \
  d=$(grep -c '^local function test_' "$f"); c=$(grep -c '^test_' "$f"); \
  if [ "$d" -gt 0 ] && [ "$c" -eq 0 ]; then echo "$f"; fi; done | wc -l
```

prints `0`. The migration batches under `3IOCdooE` are what make the new
paths live. So the new behaviour is proved by unit tests over synthetic
child output and a `TEST_TMPDIR` fixture, not by the tree's own summary —
see Acceptance.
