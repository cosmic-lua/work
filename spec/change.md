Three files, one new tool plus its fixture and its doc home.

1. **New `_build/pin_probe.tl`** — a dual-use module (`cosmic.proc`'s
   `is_main()` pattern, AGENTS.md) that decides whether a probe
   discriminates two cosmic binaries, instead of a reader deciding.
   - Exported pure function
     `verdict(baseline_code: integer, candidate_code: integer): string, boolean`
     returning the verdict TEXT and whether it discriminates. The four
     cases, exactly:
     - baseline non-zero, candidate zero →
       `"pin-probe: DISCRIMINATES (baseline refuses, candidate accepts)"`, true
     - baseline zero, candidate non-zero →
       `"pin-probe: DISCRIMINATES (baseline accepts, candidate refuses)"`, true
     - both zero →
       `"pin-probe: VACUOUS (both accept)"`, false
     - both non-zero →
       `"pin-probe: VACUOUS (both refuse; a differing message is not discrimination)"`,
       false
   - Script half: argv is `<probe.tl> <baseline-binary> <candidate-binary>`.
     For each binary run `{binary, "--check", "types", probe}` with
     `child.run`, following `_build/coldbuild_test.tl:60-83` (which
     already execs a cosmic binary this way and sets
     `COSMIC_COVERAGE = "0"` in the child's env for the same reason).
     `child.Result` carries `code: integer`, `ok: boolean`, `stdout`,
     `stderr` (`cosmic/child/types.tl:15-18`); read `code`.
   - Print, in order: a `baseline: <path>` block with that run's
     combined output and `exit=<code>`, the same for `candidate:`, then
     the single verdict line last. Printing BOTH transcripts is
     load-bearing — it is what shows a reader the two messages differed
     while the statuses did not.
   - Exit 0 when it discriminates, 1 when vacuous. Wrong argument count
     or an unreadable probe file: one error line and exit 2 (never 0,
     never 1 — a usage error must not read as either verdict).
   - Library rules apply: no throwing from the module half; the script
     half is a process boundary and may `os.exit` with a trailing
     `-- exits: <why>` (D30).

2. **New `_build/testdata/packn_probe.tl`** — the verified worked
   example from Finding 3, verbatim, two lines:
   ```
   local t = table.pack(1, "a")
   local _n: integer = t.n
   ```
   The `_` prefix is required (Finding 2) and a comment on line 1 must
   say so. `testdata/` is never embedded, and
   `_build/coldbuild_test.tl` already excludes `/testdata/` from its
   sweep (`_build/coldbuild_test.tl:49-53`), so this file is not held to
   the pinned checker — which is the whole point of it.

3. **New `_build/pin_probe_test.tl`** — header
   `--- reads: o/bootstrap/cosmic`, mirroring
   `_build/coldbuild_test.tl:1`.
   - Four pure tests over `verdict`, one per case above, asserting the
     exact verdict text and the boolean.
   - Two end-to-end tests running the PINNED bootstrap
     (`o/bootstrap/cosmic`, guarded by an `assert(fs.is_file(...))`
     with a message naming how to land it, as
     `_build/coldbuild_test.tl:63-64` does) as BOTH baseline and
     candidate: a probe of `local _x: integer = 1` written to
     `TEST_TMPDIR` must end `pin-probe: VACUOUS (both accept)`, and
     `local _x: integer = "s"` must end
     `pin-probe: VACUOUS (both refuse; …)`. Both outcomes hold under
     any checker, patched or not, so neither test can rot with a pin
     bump. The DISCRIMINATES arms need two different binaries and are
     covered by the pure tests only — say so in a comment.
   - Each `test_*` is called on the line after its `end` (AGENTS.md).

4. **`docs/build.md`** — under the existing `## Bootstrap` section
   (heading at line 132; the section's last paragraph ends at line
   148, and the file is 148 lines, well under the 500-line cap), add a
   short `### Proving a candidate carries a checker change`
   subsection: a carried tl patch reaches builders only through the
   pin, so a bump that means to obtain a patch entry must prove the
   candidate binary has it; the proof is opposite EXIT STATUS on one
   probe, never a differing message; the command is
   `o/bin/cosmic _build/pin_probe.tl <probe.tl> o/bootstrap/cosmic <candidate>`
   (the current pin's binary is already on disk at
   `o/bootstrap/cosmic` after any `bin/cosmic` run, and is the right
   baseline); `_build/testdata/packn_probe.tl` is a worked example;
   and name the unused-variable trap from Finding 2 in one sentence.
   Keep it to prose plus that one command — no procedure checklist.

`grep -c "pin-probe" docs/build.md` is 0 today; `_build/pin_probe.tl`
and `_build/testdata/` do not exist today (`ls` on both: no such file
or directory). The carried patch has 32 entries today
(`grep -h '^  \["' 3p/tl/tl_patch/*.tl | wc -l`).
