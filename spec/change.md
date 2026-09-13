`_make/runverb.tl`, `run()` (lines 136-146 on origin/main). A cast-removal
sweep turned `local self = file_of(proj, path) as File` into

```teal
local self = file_of(proj, path)
assert(self, "resolve() proved it")
```

which is the verb's only bare `assert` (`git grep -c '^\s*assert('
origin/main -- _make/runverb.tl` → 1) and the only exit in `run()` that is
not a `refuse(...)` / `stage.verdict("run", false, …)`. Replace it with the
verb's own refusal shape so a nil here prints `make: …` and a verdict line
like every other failure in the file:

```teal
local self = file_of(proj, path)
if not self then
  return refuse("no such source: " .. path)
end
```

`refuse` (runverb.tl:62-65) writes `make: <detail>` to stderr and returns
`stage.verdict("run", false, "bad target")`; reuse the wording `resolve()`
already prints for a missing source (`"make: no such source: " ..
paths[1]`, runverb.tl:90) so `_make/resolution_test.tl`'s existing
`out:find("no such source", 1, true)` check (line 136) covers both branches
without change. Delete the `assert` line; do not keep it beside the guard.

Add one test to `_make/resolution_test.tl`, in the shape of
`test_run_refuses_a_binary_name` (lines 128-135): call `runverb.run` directly
with a `prepare` stub that deletes the target file and re-scans, i.e.
`function(proj: Project, _c: string): boolean, string` that runs
`fs.remove(fs.join(proj.root, "cmd/app/main.tl"))`, then
`proj.files = project.scan(proj.root).files`, and returns `true, ""`. Assert
the exit code is non-zero and that stderr carried `no such source`. This is
the reachable path the guard exists for, so it rides the diff as a test, not
as a prose claim.

The invariant the assert encoded is true today; the change is about which
seam it is enforced at. `_make/law.tl:81` wires `runverb.resolve` as the
verb's pre-flight, but `run()` calls `resolve` again itself (line 138) and
then `prepare(proj, cosmic)` between that call and `file_of` (line 141).
`prepare_stage` (_make/init.tl:182-194) runs `stage.graph_stage`,
`assemble`, `stage.binaries_on_path` and `testrun.build` against the same
`proj`; none of them mutates `proj.files` today, but a verb-level invariant
that depends on four other modules' non-behaviour belongs behind a refusal,
not an `assert` that produces a Lua traceback in a passthrough verb whose
exit code callers branch on (runverb.tl:190-193).
