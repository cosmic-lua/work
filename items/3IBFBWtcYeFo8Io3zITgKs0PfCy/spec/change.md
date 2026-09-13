Three edits, one new module for shared internals, one new module for
corpus, and one new test file. No new files in `_fuzz/testdata/` are
committed by this item; no existing `*_fuzz_test.tl` property changes.

**Start from `origin/main`, on a fresh branch and a fresh PR.** The
item's `pr` field still names #1297, which is the bounced attempt: a
two-module shape (`corpus.tl` + `driver.tl`) that this spec replaces
with a three-module one, on a branch based at `0b2907b9`. It is closed
as superseded — read its diff for reference if it helps, do not push
to it, and hand the item over with the NEW number (`gitboard move ID
check --pr N`).

### 1. `_fuzz/detail.tl` — the shared internals both modules import

A new leaf module holding the three bodies both `driver.tl` and
`corpus.tl` need:

- `BUDGET_MESSAGE: string` — the exact string `arm_budget` throws.
- `env_integer(name: string, fallback: integer): integer` — the
  integer-env helper `driver.tl` uses for FUZZ_SEED / FUZZ_ITERS /
  FUZZ_SAVE.
- `detail_of(ok: boolean, held: any, detail: any, budget: integer):
  string` — the failure-suffix formatter (translates a pcall result
  into `"budget=%d exceeded"` / `"threw: <text>"` / a property
  message).

Rationale for a third module rather than exporting from `driver.tl`:
`corpus.tl` needs these, and `driver.tl` requires `corpus.tl` — so
importing driver from corpus would circular-require. A leaf module
neither imports.

### 2. `_fuzz/corpus.tl` — corpus dir, replay, save

New module, imports `_fuzz.detail` (for BUDGET_MESSAGE / env_integer /
detail_of), `cosmic.codec`, `cosmic.env`, `cosmic.fs`, `cosmic.hash`.
Public API:

- `dir_for(name: string): string` — returns `env.get("FUZZ_CORPUS_DIR")
  / <name>` when set (tests point it at `TEST_TMPDIR`), otherwise
  `fs.join(fs.dirname(arg[0]), "testdata", name)` — colocating the
  corpus with the fuzz test file, so the mechanism works for any
  project using `cosmic.fuzz`.
- `replay(name, check, budget, arm, disarm): boolean, string` — the
  replay pass. `arm` and `disarm` are PASSED IN by the caller
  (driver's `arm_budget`/`disarm_budget`), which breaks the circular
  require without exposing driver's debug-hook internals. Contract:
    - `fs.is_dir(dir_for(name))` — silent boolean probe. False (the
      common case) returns `(true, "")` immediately: no fs calls
      beyond the probe, no log.
    - `fs.find(dir, {recursive = false, sorted = true})` — one flat
      directory of leaf files, sorted so replay order is deterministic
      across runs and sessions. A `nil, err` here (unreadable dir
      after `is_dir` said yes) returns `(false, corpus_failure(..,
      "corpus listing failed: " .. err))` — surfaced through the
      isolated child's stderr like every other failure.
    - For each file in sorted order: `fs.read(path)` for the bytes;
      `arm(budget)` around `pcall(check, bytes)`; `disarm()`. A held
      check moves on. A false return, a throw, or a `BUDGET_MESSAGE`
      throw returns `(false, corpus_failure(name, basename, bytes,
      detail_of(...)))`. No shrinking — the input is already concrete.
- `save(name: string, input: string)` — writes when
  `detail.env_integer("FUZZ_SAVE", 0) == 1`; otherwise a no-op.
  `fs.make_dirs(dir_for(name))` (idempotent), then
  `fs.write(fs.join(dir_for(name), hash.sha256_hex(input)), input)`.
  Write errors are ignored: the failure message is the load-bearing
  output; two callers finding the same bug write identical bytes to
  the same path.
- Private `corpus_failure(name, basename, input, detail): string` —
  the replay formatter: `"%s: corpus=%s input(base64)=%s: %s"`,
  taking `codec.encode_base64(input)`. Replay has no seed, no
  iteration, no draws — inventing zeros to reuse `failure()`'s six
  slots would be a lie. `corpus=` / `iteration=` are the two
  distinguishing tokens; grepping either never false-hits the other,
  and Acceptance #4 asserts that directly.

### 3. `_fuzz/driver.tl` — call the corpus module, migrate helpers to detail

Two require lines added: `_fuzz.detail` and `_fuzz.corpus`. Three
locals removed: `BUDGET_MESSAGE`, `env_integer`, and the inline
detail-computation now folded into `detail_of` (moved to
`_fuzz/detail.tl`). Every existing use site swaps to
`detail.BUDGET_MESSAGE` / `detail.env_integer` /
`detail.detail_of`.

Two new call sites in `run_in_process`:

- **Before** the `for i = 1, iters` loop: `local ok, msg =
  corpus.replay(opts.name, opts.check, budget, arm_budget,
  disarm_budget); if not ok then return false, msg end`. The wall-clock
  cap is inherited from `spawn_isolated`'s `timeout_ms` (30000 ms
  default), which caps the whole child — corpus pass and generated
  loop together.
- **On the failing-generated branch**, after shrinking and before
  constructing the `failure()` message: `corpus.save(opts.name,
  minimized_input)`.

`failure()` and `arm_budget`/`disarm_budget` stay in `driver.tl` —
they use `codec` (already imported) and `debug.sethook` respectively,
and no other module needs them. Their signatures do not change; every
existing `driver_test.tl` substring assertion (`iteration=1`,
`iteration=5`, etc.) keeps meaning what it means.

### 4. `_fuzz/driver_corpus_test.tl` — the six new tests

New test file (mandatory: `driver_test.tl` is 406/500 with no room
for six more tests plus their helpers). All tests use
`FUZZ_CORPUS_DIR=$TEST_TMPDIR` and, at teardown, restore every driver-
visible env var they touched. Every test uses
`driver.run_unisolated`, so none enters the crash path (see Non-goals
bullet 5).

The file holds exactly these SIX tests, each called on the line after
its `end` (house rule), and no others:

1. `test_no_corpus_dir_is_silent` — Acceptance #4
2. `test_corpus_entry_failure_is_reported` — Acceptance #5
3. `test_corpus_runs_before_generated_in_sorted_order` — Acceptance #6
4. `test_fuzz_save_writes_content_addressed` — Acceptance #7
5. `test_fuzz_save_unset_writes_nothing` — Acceptance #7
6. `test_fuzz_save_is_idempotent` — Acceptance #8

Helpers (`restore()`, `seed_corpus_file`, env-savers) are exempt from
the call-where-defined rule, being called from the tests.

### 5. Env grammar

Only three env vars are new to this item:

- `FUZZ_CORPUS_DIR` — overrides the default corpus root. Read only in
  tests. Its default (unset) is the colocated `testdata/` shape.
- `FUZZ_SAVE` — read via `detail.env_integer("FUZZ_SAVE", 0)`. Any
  value other than `1` (unset, `"0"`, `"true"`, garbage) is a no-op.
  No default-on path, ever; CI never sets it — verified by
  Acceptance #6.
