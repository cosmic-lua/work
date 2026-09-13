Register the capability the two cases actually need, and move exactly
those two cases into a file that declares it. `--- requires:` is a
WHOLE-FILE contract (`_tool/testplan.tl:71` reads the declarations for
the whole source), so declaring it on `_make/lockdir_test.tl` as it
stands would skip its six mode-independent cases under root as well —
that is the reason for the split, not tidiness.

**1. The capability.** `_tool/testcap.tl` (140 lines, 360 under the
cap). Add a probe beside `probe_nanosecond_timestamps` (lines 42-61) and
a fourth entry in `REQUIREMENTS` (lines 63-79), keyed
`mode-enforcement`, with `required_linux_ci = true` — the CI lanes are
non-root, so absence there means the lane changed and must go red.

The probe does what the tests do, not a uid check: a uid test would miss
a filesystem that ignores modes and would be wrong for a non-root
process holding `CAP_DAC_OVERRIDE`. Under `temp_dir`, create a scratch
directory, `fs.set_mode(dir, fs.octal("500"))`, attempt
`fs.write(fs.join(dir, "probe"), "x")`, restore mode `700` and remove
the directory, and report `available = false` when that write SUCCEEDED,
with a detail naming the cause ("directory mode 0500 did not refuse a
write — root or CAP_DAC_OVERRIDE"). A probe that cannot create its own
scratch directory reports `available = false` with the `fs` error as
detail; it must never throw and must leave nothing behind under
`temp_dir`, because `_tool/testplan.tl`'s `policy_evidence` (line 100)
runs every registered probe on every planning pass.

**2. The split.** New file `_make/lockdir_mode_test.tl`, header
`#!/usr/bin/env cosmic`, then `--- reads: _make/lockdir.tl`, then
`--- requires: mode-enforcement`, then a one-line doc comment. It
carries a local `scratch(name)` helper copied from
`_make/lockdir_test.tl:12-17` and two top-level `local function test_*`
definitions — no self-calls; the file is enrolled by definition
(AGENTS.md, D29). Move into it, verbatim:

- From `test_terminal_errno_and_turnover_classification`
  (`_make/lockdir_test.tl:170`), the two blocks that set a mode:
  lines 179-184 (`local empty` through the `"absent token must not
  attempt rmdir"` assert) and lines 186-192 (`local eacces` through the
  `"terminal EACCES is not ENOTEMPTY"` assert). They become one case,
  `test_permission_denied_is_terminal`, opening with `local root =
  scratch("mode-terminal")` and `local token =
  "550e8400-e29b-41d4-a716-446655440000"` — the token literal is copied,
  not moved, because line 177's ENOTDIR assert still uses it.
- `test_cleanup_error_is_not_contention` in full, lines 329-347, moved
  unchanged.

Delete those same lines from `_make/lockdir_test.tl` (415 lines today;
`wc -l` → `415`). What stays in
`test_terminal_errno_and_turnover_classification` is the ENOTDIR pair at
lines 175-177 and the whole turnover half from line 194 to the function's
end at line 327 — none of it calls `fs.set_mode`, so the function keeps
its name and keeps running everywhere. After the move, `grep -n
"set_mode" _make/lockdir_test.tl` must return no hit; that grep is the
check that the split is complete.

**3. The registry's two literal mirrors.** `_tool/testrun_contract_test.tl`
lines 224-232 build `available` and `absent` maps that name all three
current capabilities so `test_policy_evidence_changes_with_probe_answer`
is hermetic. Add `["mode-enforcement"] = {available = true, detail = ""}`
to both, so the new probe is not silently answered by the live host in a
test that exists to compare two injected answers.

**4. The prose that enumerates them.** `AGENTS.md:375` reads
"(`loopback-listen`, `ape-assimilation`, and `nanosecond-timestamps`) are
mandatory and absence fails the gate" — add `mode-enforcement` to that
list. `_build/doc_symbols_test.tl` declares `--- reads: docs skills
README.md AGENTS.md`, so it re-runs on this edit by design.

**5. One thing to expect, not to fix.** `policy_evidence` folds one
availability bit per registered probe into the record tool stamp
(`_tool/testplan.tl:100-115`), so adding a fourth requirement changes the
stamp and every test record re-runs once on the first build after this
lands. That is the mechanism working; do not try to keep the stamp
stable.

**Bounds land as the two moved cases themselves.** They are the
regression test: with the header in place, `o/bin/cosmic --make test
_make/lockdir_mode_test.tl` must report the file `UNAVAILABLE` (not
FAIL) under a root runner, and `o/bin/cosmic --make test
_make/lockdir_test.tl` must pass there. Add one case to
`_tool/testrun_contract_test.tl` (272 lines) in the shape of
`test_capability_requirement_only_gates_execution` (line 241): resolve a
fixture source declaring `--- requires: mode-enforcement` with an
injected `capabilities = {["mode-enforcement"] = {available = false,
detail = "injected"}}`, and assert `plan.unavailable ==
"mode-enforcement"` under `profile = "local"` with `plan.fatal` false,
and `plan.fatal` true under `profile = "linux-ci"` — the two halves of
what `required_linux_ci = true` buys.

This repo has no committed coverage floor to edit (AGENTS.md: "Coverage
has no committed floor to hand-edit"); `.github/workflows/pr.yml:222`
states `--min 76 --min-file 0` and nothing here is a per-file floor
change. The new probe adds no nil-admitting return and no cast, so
`_build/nil_returns_baseline.tl` and `_build/casts.tl` gain no row.
