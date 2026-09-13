Seven files, plus the coverage floor.

**1. New `_perf/baserun.tl`** — the ONE definition of "measure a
baseline binary against the tree's `_perf`", so the workflow and the
gate's retry cannot drift apart. Two exported functions plus a script
mode:

```teal
--- @return string|nil Absolute path of the manifest written
local function ensure_root(root: string, build: string): string | nil, string
local function argv(bin: string, modules: string, extra: {string}): {string}
```

`ensure_root` makes `<root>/<build>/perf/treeroot/o`, symlinks
`<root>/_perf` → `treeroot/_perf` and `<root>/<build>/_perf` →
`treeroot/o/_perf` (idempotent: skip an existing link), writes
`<root>/<build>/perf/tree.modules` holding exactly
`root <abs treeroot>` and `build o`, and returns that path. It creates
NO other entry under `treeroot` — that emptiness IS the fix.
`argv` returns `{bin, "--modules", modules, "o/_perf/run.lua", extra…}`.
Script mode (`proc.is_main()`): parse `--bin PATH`, pass every other
argument through, `ensure_root(fs.cwd(), "o")`, `child.run` with
`stdout`/`stderr` inherited, exit with the child's code (three
`os.exit` sites, each carrying `-- exits: process boundary`).
Measured: this exact prototype type-checks under the PIN
(`o/bootstrap/cosmic --check types --include-dir "$D" _perf/baserun.tl`
→ passed), and `bin/cosmic --make run _perf/baserun.tl --bin
o/bootstrap/cosmic --only time --samples 1 --min-secs 0.05 --out
o/perf/prev-probe.json` ran under the fence and wrote
`bin_sha 90ff7f246b3f…` (the OLD binary). The entry must be
`o/_perf/run.lua`, not `_perf/run.tl`: a `.tl` entry is type-checked
through the binary's include path, which finds `/zip/.tl/_perf/*.tl`
before any `require` runs.

**2. New `_perf/baserun_test.tl`** — cases: `ensure_root` in
`TEST_TMPDIR` writes a manifest whose `root` line points at
`treeroot`; **the constructed root's entries are exactly `_perf` and
`o`, and `o`'s entries exactly `_perf`** (the structural wall against
the `root $PWD` over-capture); a second `ensure_root` call is
idempotent; `argv` puts `--modules` before the entry and appends extras
in order. Each `test_*` called on the line after its `end`.

**3. `_perf/gate.tl`** — in `measure_baseline` (currently 351-361),
replace the hardcoded `{baseline_bin, "_perf/run.tl", "--out", out}`
with `baserun.argv(baseline_bin, baserun.ensure_root(cwd, "o"), …)`,
requiring `_perf.baserun` beside the existing `local child =
require("cosmic.child")`. Rewrite the comment above it to say the shape
is `baserun`'s, shared with release.yml, and why (the retry must
resolve `_perf` exactly as pass 1 did). A failed `ensure_root` returns
1 with its message on stderr, like the existing child failure. Headroom:
`wc -l _perf/gate.tl` = 406, 94 lines under the 500 cap.

**4. `.github/workflows/release.yml`** — in the "compare against the
previous release" step, replace line 181

```
o/perf/prev/cosmic-lua _perf/run.tl --out o/perf/prev/perf.json
```

with

```
o/bin/cosmic --make run _perf/baserun.tl --bin o/perf/prev/cosmic-lua \
  --out o/perf/prev/perf.json
```

Nothing else in the step moves: `baseline.tl`, the SKIP branch, the
`chmod +x`, `--baseline-bin`, the `| tee`, `pipefail` and `exit "$rc"`
all stand. And rewrite the parenthetical at lines 162-163 — "(the
previous binary measures its own embedded scenario set, exactly as its
stored numbers did)" — which this change falsifies. The phrase
`embedded scenario set` must not survive it: that is precisely what
stops being true (see *What this changes about the gate's meaning*).

**5. `_perf/skew_test.tl`** — build a `_perf`-only include directory in
`TEST_TMPDIR` (`fs.symlink(fs.join(cwd, "_perf"), fs.join(tmp,
"_perf"))`), assert its entries are exactly `{"_perf"}` before using
it, and pass `--include-dir <that dir>` to the child `--check types`.
Then rewrite the header and the assert message:

- delete "`_perf.*` resolves from the tree at cwd" — false in every
  context measured here and in the sidecar's earlier passes;
- say what the guard now checks: every non-test `_perf/**` source
  against the PIN's `cosmic.*` declarations and against the TREE's own
  `_perf.*` declarations, because after change 4 the baseline lane runs
  the tree's `_perf` on the previous release's `cosmic`;
- say why the include dir is scoped: `--include-dir .` at the repo root
  resolves `cosmic.*` from the tree and silently defeats the guard
  (measured: exit 0 with an invented API in use);
- the failure message stops prescribing the tolerant-map-view remedy as
  the only reading. Both readings: a `cosmic` API newer than the pin
  takes the map view or waits for the pin; anything else is a genuine
  type error in a `_perf` file.

Headroom: `wc -l _perf/skew_test.tl` = 70.

**6. `_build/workflows_test.tl`** — extend
`test_the_release_perf_compare_propagates_its_verdict` (or add one
beside it) asserting the compare step's baseline measurement goes
through `_perf/baserun.tl` and that the step body does NOT contain
`cosmic-lua _perf/run.tl`. Headroom: `wc -l _build/workflows_test.tl` =
329.

**7. `skills/optimize/SKILL.md`** — its warning that `$BIN
o/_perf/run.lua …` "reads like the fix and is not" stays true for a
BARE run; add the one exception in the same bullet: with `--modules`
naming a `_perf`-scoped root it resolves the tree's `_perf` against the
binary's own `cosmic`, which is what the release baseline uses and what
`_perf/baserun.tl` builds.

**Coverage.** New files move the ratchet: run exactly the regen the
gate's failure prints (`bin/cosmic --make coverage --baseline`) and
commit `.cosmic-coverage`. Never weaken the gate any other way.
