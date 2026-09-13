- Do NOT convert the peers lane to `_perf/baserun.tl` or a `--modules`
  run. That is the question this item settles, and the answer is no.
- Do not touch `_perf/**` at all. In particular `_perf/baserun.tl`,
  `_perf/peers/**`, and `_perf/skew_test.tl` — whose cost-versus-value
  question belongs to `3IVKRdTZ` and must not be pre-empted here.
- Do not touch `_perf/compare.tl` or `_perf/gate.tl`: PRs #1485
  (`3IUBNQZZ`) and #1486 (`3IVLAF3Z`) are open over both. This slice is
  file-disjoint from them by construction; keep it so, and it needs no
  serialization against either.
- Do not modify `workflows`, `lines_with`, `step_body`, `jobs_in`,
  `containerised_jobs`, `UNCONTAINERISED`, the `Job` record, or any
  existing test in `_build/workflows_test.tl`.
- Do not change the peers job's uncontainerised exemption, its runner
  image, its artifact names, or its `timeout-minutes` — the peer
  versions are deliberately the runner image's.
- Do not add self-call lines (`test_foo()`) to
  `_build/workflows_test.tl`. AGENTS.md's "test files call each test
  where they define it" does not describe this file: it is runner mode,
  and a self-call would double-execute the case.
- No YAML parser, no new dependency, no fixture workflow, no
  parameterised workflow path. Line-scanning, as the file already does.
- No verdict-line format changes anywhere.
