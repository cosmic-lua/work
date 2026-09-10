## Evidence

Two cases in `_make/lockdir_test.tl` fail under a root runner, as a hard
product FAIL indistinguishable from a real regression. Measured on
2026-09-10 in a pristine `/home/user/cosmic` at `5c62eb29`:

```
$ whoami
root
$ id -u
0
$ o/bin/cosmic --make test _make/lockdir_test.tl
...
        o/_make/lockdir_test.lua:193: terminal EACCES is not ENOTEMPTY
        o/_make/lockdir_test.lua:345: cleanup EACCES is not busy
    8 checks: 6 passed, 2 failed
test: FAIL (1 of 1 file)
```

(Those are lines in the compiled `o/_make/lockdir_test.lua`; the source
assertions are `_make/lockdir_test.tl:192` and `:344`.)

Both cases force a failure by making a directory unwritable. Root's
DAC override makes that a no-op, so the operation they expect to be
refused succeeds instead:

```
$ o/bin/cosmic /dev/stdin <<'EOF'
local fs = require("cosmic.fs")
local d = "/tmp/modeprobe-" .. tostring(os.time())
assert(fs.make_dirs(d))
assert(fs.set_mode(d, fs.octal("500")))
local ok, err = fs.write(d .. "/probe", "x")
print("write under 0500 dir ->", ok, err)
EOF
write under 0500 dir ->	true	nil
```

The mechanism the runner has for exactly this — a declared host
capability that reports `UNAVAILABLE` instead of `FAIL` — is not used
here: `_make/lockdir_test.tl`'s header is `#!/usr/bin/env cosmic` then
`--- reads: _make/lockdir.tl` and nothing else, and the registry has no
capability that would cover it:

```
$ grep -n '^  \["' _tool/testcap.tl
64:  ["loopback-listen"] = {
69:  ["ape-assimilation"] = {
74:  ["nanosecond-timestamps"] = {
```

The supported lane is not affected: every Linux job in
`.github/workflows/pr.yml` runs the gate as a created non-root user
(`grep -n "runuser -u builder" .github/workflows/pr.yml` → lines 183,
184, 220, 266, 304, 343, 412), so mode enforcement holds there and a
requirement registered as mandatory under `linux-ci` stays honest.

Cost on 2026-09-10: one full investigation confirming it reproduces on
unmodified `main` before a completed, verified board item's own `--make
ci` run could be trusted, and the same investigation again for every
future full-gate run in a root environment.

## Change

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

## Non-goals

- **`_make/lockdir.tl` is not touched.** The build-writer lock is not
  broken; only the tests' undeclared non-root assumption is.
- **Do not put `--- requires:` on `_make/lockdir_test.tl`.** It would
  skip six mode-independent cases under root, trading a false FAIL for
  silent loss of the coverage that matters most in that environment.
- **Do not gate on the uid.** `os.getenv("USER")`, a `geteuid` binding,
  or "am I root" in any form is rejected: it is wrong for
  `CAP_DAC_OVERRIDE` without root and for a filesystem mounted without
  mode enforcement, both of which the behavioural probe catches.
- **Do not register it as `required_linux_ci = false`.** Making absence
  non-fatal everywhere would let the supported lane start running as
  root and silently stop exercising these two cases — the exact failure
  mode this item is about, moved one level up.
- **No per-case skip mechanism.** The runner's contract is whole-file
  (`_tool/testplan.tl`), and adding a per-function variant is a change to
  the test runner, not to this test. The split is how a file with mixed
  requirements is expressed today.
