In `_perf/gate.tl`, give the retry its own output path and leave the
gate's arguments alone.

- Add a small local that derives the retry path from the current one:
  strip a trailing `.json` and append `-retry.json`
  (`o/perf/current.json` → `o/perf/current-retry.json`). Beside the
  caller's own output, not in a temp dir: the directory is already one
  the caller writes to, there is nothing to clean up, and a failed gate
  leaves the run that failed it available to read.
- In `gate_inner`, replace the three uses of `opts.current` that follow
  the first `compare_once` with that retry path: `opts.measure(retry)`,
  the post-retry `identity_refusal(opts.baseline, retry, false)`, the
  second `compare_once(opts.baseline, retry, opts.threshold)`, the A/A
  `identity_refusal(retry, opts.selfcheck_b, true)`, and the triaged
  `compare_once(opts.baseline, retry, opts.threshold, retry,
  opts.selfcheck_b)`. The first `identity_refusal` and the first
  `compare_once`, both before any measurement, keep reading
  `opts.current`.
- Print the retry path when the retry runs, on the existing
  "re-measuring once to filter noise" line, so the file the verdict
  came from is named in the output.
- Rewrite the `usage` string to mark each argument, since two of the
  five paths across the two modes are outputs:
  ```
  usage: gate.lua compare BASE.json CUR.json SELFB.json [--threshold PCT] <run args...>
           BASE, CUR: read; SELFB: written by the A/A pass
           a flagged regression re-measures into CUR's sibling CUR-retry.json
         gate.lua selfcheck A.json B.json [--threshold PCT] <run args...>
           A, B: both written — selfcheck's job is to measure twice
  ```

In `_perf/gate_test.tl`, add `test_retry_does_not_overwrite_current`: a
flagged regression whose injected `measure` writes a quiet result to
whatever path it is handed; assert the gate passes, that the path it
was handed ends in `-retry.json`, and that reading `CUR.json` back
returns the original 1300 `wall_ns` unchanged. Model it on
`test_flagged_regression_retries_then_passes` (`:54`), which already
has the shape.

In `skills/optimize/SKILL.md`, at the `gate.tl compare` snippet
(`:73`) and in the paragraph at `:83` that explains the retry and A/A
triage, say which paths the gate reads and which it writes, and that
the retry lands in `CUR-retry.json`. Same one-line note in
`skills/optimize/measurement.md` beside its `gate.lua selfcheck`
mention (`:56`), that selfcheck writes both its arguments.
