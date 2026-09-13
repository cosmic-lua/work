1. `_perf/compare.tl` (357 lines today; `wc -l < _perf/compare.tl` = 357,
   143 lines of headroom under the 500-line cap). Add, immediately above
   the `--- Refuse a pair of results files` doc block that opens
   `identity_refusal`:

   ```teal
   local function same_binary(a_res: pt.Results, b_res: pt.Results): boolean
     local sa = a_res.meta and a_res.meta.bin_sha
     local sb = b_res.meta and b_res.meta.bin_sha
     return sa ~= nil and sb ~= nil and sa == sb
   end
   ```

   with a `---` doc comment saying that absence is never proof, and that
   the predicate is positive because reading
   `identity_refusal(...) == nil` as "same binary" is what admitted
   stampless files. Declare `same_binary: function(a_res: pt.Results,
   b_res: pt.Results): boolean` on the `compare` record IMMEDIATELY
   ABOVE the existing `identity_refusal:` field (`_perf/compare.tl:337`)
   and export it on `M` immediately above `identity_refusal =
   identity_refusal,` (`:349`). `grep -c "same_binary" _perf/compare.tl`
   is 0 today.

2. `_perf/compare.tl`, inside `identity_refusal`'s `if not sa or not sb
   then` branch (`:308-315`): keep the existing stderr line, then, when
   `same` is true, RETURN a refusal string instead of `nil`. Wording:
   name both paths and say that an unidentified pair is not a noise
   floor. When `same` is false, still `return nil`. Extend the function's
   doc comment (the `A file with no bin_sha cannot be checked either
   way` paragraph, `:297-299`) to state the asymmetry: absence cannot
   prove sameness, and is not evidence of difference either.

3. `_perf/gate.tl` (460 lines today; `wc -l < _perf/gate.tl` = 460, 40
   lines of headroom). Add a path-level `same_binary(a: string, b:
   string): boolean` **immediately ABOVE the `--- The identity rule of
   `compare.identity_refusal`, over two paths.` doc block at `:107`** —
   not below the function it accompanies. It loads both files with
   `compare.load_results`, returns `false` when either fails to load,
   else `compare.same_binary(ra, rb)`. **The placement is load-bearing,
   not taste:** PR #1485 (`3IUBNQZZ`, in `check`) inserts its own
   `print_report` helper into the slot directly BELOW the path-level
   `identity_refusal` and directly above `--- Print the gate's verdict`.
   Measured on a prototype carrying this exact Change, at `origin/main`
   = `3ff022d3`: with the helper placed below, `git merge-tree
   --write-tree HEAD refs/pull/1485/head` exits 1 with `CONFLICT
   (content): Merge conflict in _perf/gate.tl`; with the helper placed
   above, it exits 0.

4. `_perf/gate.tl:266`: replace
   `if identity_refusal(retry, opts.current, true) == nil then` with
   `if same_binary(retry, opts.current) then`. Leave the comment at
   `:261-264` as it stands — it now describes the code.

5. `_perf/gate_test.tl` (380 lines today, after D34's split moved 99
   lines out to `_perf/gate_strike_test.tl`; 120 lines of headroom).
   Five existing tests fabricate stampless fixtures and reach a
   `same = true` path, where they would now hit the new refusal or lose
   a control. Stamp their fixtures IN PLACE — add a third argument to
   the existing `write_results` calls, changing no assertion and no
   expected exit code: the `base` file gets `"aaaa1111"`, the `cur` file
   and every file the injected `measure` writes get `"bbbb2222"`. The
   five, at today's line numbers:
   `test_persistent_regression_triaged_as_noise_passes` (`:99`),
   `test_large_regression_survives_unstable_selfcheck_and_fails` (`:131`),
   `test_real_regression_survives_triage_and_fails` (`:154`),
   `test_selfcheck_reports_quiet_and_noisy` (`:188`),
   `test_the_gate_triages_against_every_measured_control` (`:360`).
   `test_selfcheck_reports_quiet_and_noisy` has no base/cur pair — it is
   an A/A run, so BOTH of its files (`out == a and 1000 or 1010` at
   `:193`, and the `1500` at `:201`) get `"bbbb2222"`.
   Exactly two lines cross 90 columns once the argument is added — `:370`
   (79 → 91) and `:372` (83 → 95), both trailing comments inside
   `test_the_gate_triages_against_every_measured_control` — so move those
   two comments onto their own line above. Measured with
   `awk 'NR>=99 && /write_results\(/ {print NR, length($0)+12}'
   _perf/gate_test.tl`: every other stamped line lands at 88 columns or
   less, and `awk 'length>90' _perf/gate_test.tl | wc -l` is 0 today.
   Touch nothing else in this file; in particular leave
   `test_a_file_without_a_sha_is_not_refused` (`:340`) exactly as it is,
   since the `same = false` behaviour it pins does not change — traced:
   its only identity check is `_perf/gate.tl:142`, which passes
   `same = false`, and its 1000-vs-1010 pair returns 0 before any
   `same = true` call site is reached.

   Only three of the five FAIL without the stamp; the other two
   (`large_regression`, `real_regression`) expect exit 1 and would keep
   passing for the wrong reason. Stamp all five anyway — a test that
   passes because the gate refused, rather than because it triaged, is
   not testing what it names.

6. `_perf/gate_strike_test.tl` (214 lines): **no change.** Every fixture
   in it is already stamped — `grep -c 'write_results([a-z_]*, [0-9]*)'`
   and the equivalent for `write_multi` return 0 unstamped calls — so it
   passes unedited. Verified by reading every fixture-writing line in it:
   `:46, :47, :53, :66, :67, :73, :89, :90, :96, :102, :118, :119, :124,
   :129, :146, :147, :151, :155, :171, :172, :176, :180, :196, :197,
   :203, :207` all carry a sha argument.

7. New file `_perf/gate_identity_test.tl` (~95-120 lines), holding the
   binary-identity rules, in the same style as `_perf/gate_test.tl` and
   with its own local `write_results` / `paths` helpers (do NOT
   `require` the other test file). Four tests:
   - `test_a_stampless_current_is_not_a_control` — the constructed case
     above verbatim: `base` `"aaaa1111"` 1000, `cur` stampless 2000,
     `measure` writes 1400 then 1390 both `"bbbb2222"`; asserts
     `code == 1` and `calls == 2`.
   - `test_a_stampless_aa_pair_is_not_a_noise_floor` — `base`
     `"aaaa1111"` 1000, `cur` `"bbbb2222"` 1300, `measure` writes
     stampless 1300 then stampless 1800 (a swing that would otherwise
     buy the +30% full credit); asserts `code == 1`.
   - `test_stampless_selfcheck_refuses` — `gate.selfcheck` whose
     `measure` writes stampless 1000 and 1010; asserts `code == 1`.
   - `test_a_control_that_will_not_load_is_not_admitted` — `base`
     `"aaaa1111"` 1000, `cur` `"bbbb2222"` 2000, and the second
     `measure` call removes `cur` after writing its own output; asserts
     `code == 1`. This one covers the load-failure branch of the new
     helper; the first three are the ones that fail without the fix.
   Define the tests only — write NO `test_x()` self-call lines. This is
   a D29 RUNNER-MODE file, and the two neighbours are the same:
   `grep -c '^test_' _perf/gate_test.tl` = 0 and
   `grep -c '^test_' _perf/gate_strike_test.tl` = 0 today. Do not read
   AGENTS.md's "test files call each test where they define it" as
   binding here; a zero-self-call `_perf` test file is legal and
   self-invoking, and the runner is what calls them (`3IY0HUUk`).
   Corollary, because it costs an hour otherwise: a bare
   `o/bin/cosmic _perf/gate_identity_test.tl` is a SILENT no-op on a
   runner-mode file and exits 0 having run nothing (`3IUKyP4L`). Verify
   only through `--make test`, as Acceptance 2 does.

8. If the coverage ratchet complains, run exactly the regeneration
   command its failure message prints (today that is
   `bin/cosmic --make coverage --baseline`) and commit the result.
   Both files carry floors — `.cosmic-coverage:111` is
   `_perf/compare.tl 105/107` and `:112` is `_perf/gate.tl 164/208` — so
   a regen is likely, not hypothetical. Never lower a floor to
   accommodate an uncovered new branch; cover it instead.

**Capacity, measured, because this file is the tight one.**
`_perf/gate.tl` is 460 today. The prototype of this Change makes it 473.
PR #1485 alone makes it 478. The merge of both — read out of
`git merge-tree --write-tree` and not estimated — is **491 lines, 9
under the 500-line cap.** `_perf/compare.tl` after both is 415. So keep
the new gate.tl helper to the ~13 lines the prototype used, and do not
take the opportunity to expand a neighbouring comment.

**Composition with the one unreviewed PR that touches `_perf/gate.tl`.**
Re-verified 2026-08-28 with `git merge-tree --write-tree` from a scratch
commit carrying this exact Change (helper placed per step 3), at
`origin/main` = `3ff022d3`: against `refs/pull/1485/head` — **rc=0,
clean**. The two blockers this item once carried have both MERGED:
`3IVF3HbV` / #1480 as `3ff022d3`, and `3IVL9t0P` / #1483 as `b0aeb1dd`,
so their branches are no longer a composition question. No blocker edge
is needed in either direction, but see `## Non-goals` for the
serialization note on #1485.
