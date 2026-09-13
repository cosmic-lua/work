Name the third form, and pin it with a test, in five places.

1. `docs/guides/checking.md` (406 lines today; `wc -l <
docs/guides/checking.md` = 406). Add one new `## Which Checker Answered`
section, placed immediately BEFORE the existing final section `##
Include Directories` (line 404; `grep -n "^## " docs/guides/checking.md`
lists `## Discarded Errors` at 365 and `## Include Directories` at 404).
It states, in this order:

   - `cosmic --check types` always answers from the Teal checker the
     RUNNING binary embeds, including cosmic's carried patch entries
     (`3p/tl/tl_patch/`).
   - It never executes the file it checks — `handle_check_types` reads
     the source and hands the text to `cosmic.teal.check` — so a
     `package.loaded["tl"]` or `package.preload["tl"]` assignment
     written inside the checked file never runs. Such a probe reports
     the shipped checker's verdict, at exit 0, with nothing logged.
   - A modified `tl.lua` placed on `package.path` is ignored for the
     same class of reason: the binary's `/zip` searcher outranks the
     file searcher.
   - To measure a DIFFERENT checker, swap it in the checking process
     before the first check: `_make.patch`'s `reverse` installs a
     de-patched copy into `package.loaded["tl"]`, which `require` reads
     before any searcher, and `cosmic.teal.check` then answers from it.
     The worked, gated recipe is `_make/patch_test.tl`'s
     `test_reverse_flips_the_checker_on_the_real_pin` and
     `test_reverse_flips_the_metatable_value_type` — copy those, do not
     re-derive them.
   - `debug.getinfo(require("tl").process_string, "S").source` names
     which bytes answered: `@/zip/tl.lua` is the shipped copy.
   - A probe script must run under `cosmic --make run` to load the
     tree's `_make/patch.tl`; a bare `cosmic script.tl` resolves
     `require("_make.patch")` to `@/zip/_make/patch.lua`.

   Every fenced block this section adds is tagged ```text or ```bash,
   never ```teal or ```lua. `_build/snippets_test.tl` compiles every
   ```teal/```lua fence under `docs/` with warnings-as-errors and
   asserts it is a formatter fixpoint; the probe recipe's real code
   already lives, gated, in `_make/patch_test.tl`, and a second copy in
   a guide would be a second thing to keep compiling.

2. `_make/patch.tl` (359 lines). Extend the existing "**Probing an
entry.**" doc-comment paragraph (lines 22-28) with one sentence naming
the third form: `cosmic --check types` on a file that preloads `tl` is
inert because the checker never runs the file, and pointing at `cosmic
--docs guide.checking`.

3-5. `3p/tl/tl_patch/ast_cache.tl` (175 lines), `closure.tl` (355),
`narrow.tl` (433 — 67 lines of headroom under the 500-line cap). Each
carries the same "Probing an entry:" plain-comment paragraph
(ast_cache.tl:19-24, closure.tl:53-58, narrow.tl:18-23; `grep -c
"Probing an entry"` = 1 in each). Add the same one sentence to each, so
the four copies stay identical.

6. `_cli/main_handlers_test.tl` (240 lines; 260 of headroom). Add one
test that pins the behaviour the guide now asserts, so the prose cannot
go stale silently: write a file under `TEST_TMPDIR` whose first line is
`package.loaded["tl"] = dofile("<a path under TEST_TMPDIR that does not
exist>")` followed by the guarded `R | nil` index above, run it through
the built binary with the file's existing `cli("--check", "types",
path)` helper, and assert exit 0 and that stdout contains `Type check
passed`. Name it
`test_check_types_ignores_a_preload_written_in_the_checked_file`.

   `_cli/main_handlers_test.tl` is a RUNNER-MODE file: measured today,
   `grep -c "^local function test_" _cli/main_handlers_test.tl` = 15 and
   `grep -c "^test_" _cli/main_handlers_test.tl` = 0. Define the new
   function and do NOT call it — a self-call would double-execute it
   under the runner. Verify only through `bin/cosmic --make test`; a
   bare `cosmic _cli/main_handlers_test.tl` is a silent no-op on a
   runner-mode file (`3IUKyP4L`).

7. `docs/design/nil-flow.md` (457 lines) — the narrowing census, and the
surface a session probing a narrowing rule reads first. Add one sentence
near its top pointing at `cosmic --docs guide.checking` for how to probe
which checker answered.

## Non-goals

- No mechanism that makes `--check types` honour a preload. It reads
  source text and never executes it; running the checked file inside the
  checker is a category change, not a fix.
- No warn-on-`package.loaded["tl"]` lint over checked sources. The
  pattern cannot separate a probe's preload from a legitimate in-process
  swap: `_make/patch_test.tl` assigns `package.loaded["tl"]` four times
  today (lines 271, 285, 314, 328) in a file that IS run, and
  `cosmic/teal.tl:19` reads it. A rule with a measured false positive in
  the tree is not a gate.
- Do not touch `cosmic/searcher.tl` (498 lines, `wc -l <
  cosmic/searcher.tl` = 498 — 2 lines of headroom). Its `/zip`-first
  precedence is deliberate and is not implicated here: `--check types`
  runs no searcher over the checked file at all.
- Do not change `_make/patch.tl`'s `reverse` behaviour, its `Options`
  record, or `_make/patch_test.tl`'s existing assertions.
- Do not change the `Type check passed: <file>` line or `--check types`
  exit codes — `_cli/main_handlers_test.tl` and gate consumers parse
  them.
- Do not document script-vs-project `require` resolution in general;
  that is `3IK31i1L`. Say only the one sentence the probe needs.
- No `*_example.tl` for the probe, and no new module: the recipe stays
  the one gated copy in `_make/patch_test.tl`.

## Acceptance

- `bin/cosmic --make ci` ends `ci: PASS`.
- `bin/cosmic --make test _cli/main_handlers_test.tl` passes, including
  `test_check_types_ignores_a_preload_written_in_the_checked_file`.
- `grep -c "^test_" _cli/main_handlers_test.tl` = 0 (runner mode is
  preserved; it is 0 today).
- `grep -c "^local function test_" _cli/main_handlers_test.tl` = 16 (15
  today).
- `bin/cosmic --make test _build/snippets_test.tl` passes (no ```teal or
  ```lua fence was added to the guide).
- `bin/cosmic --make test _build/guides_test.tl` passes.
- `bin/cosmic --make test _make/patch_test.tl` passes unchanged — the
  recipe the guide points at still works.
- `bin/cosmic --docs guide.checking | grep -c "Which Checker Answered"`
  = 1 (0 today, so the section reaches the binary and not only the
  repo).
- `grep -c -- "--check types" _make/patch.tl` ≥ 1,
  `grep -c -- "--check types" 3p/tl/tl_patch/ast_cache.tl` ≥ 1,
  `grep -c -- "--check types" 3p/tl/tl_patch/closure.tl` ≥ 1,
  `grep -c -- "--check types" 3p/tl/tl_patch/narrow.tl` ≥ 1 (each is 0
  today).
- `grep -c "guide.checking" docs/design/nil-flow.md` ≥ 1 (0 today).
- `wc -l < 3p/tl/tl_patch/narrow.tl` ≤ 500 and `wc -l <
  docs/guides/checking.md` ≤ 500.
