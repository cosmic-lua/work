**1. `cosmic/check.tl` — add `refuses`.** Insert directly after `truthy`
and before `failed`, verbatim:

```teal
--- Assert that a call refuses arguments its declared signature forbids.
--- The call is made through `any`, so a test can pass the malformed value
--- the declared types exist to prevent, and the refusal comes back typed:
--- one cast here instead of one at every probe and one on every value read
--- off it. Throws when the call returns a value instead of refusing, or
--- refuses with an empty message.
--- @param f any The function to call, whose declared signature forbids these arguments
--- @param ... any The arguments to call it with
--- @return string The message the call refused with
local function refuses(f: any, ...: any): string
  -- cast: the probe calls past the declared signature, which is the point
  local call = f as function(...: any): (any, any)
  local value, err = call(...)
  local message = tostring(err)
  if value ~= nil or err == nil or message == "" then
    error(string.format("refuses: expected a refusal, got (%s, %s)",
        render(value), render(err)), 2)
  end
  return message
end
```

and declare it on the module record and the table, both immediately after
`must`:

```teal
  refuses: function(f: any, ...: any): string
```
```teal
  refuses = refuses,
```

`error(..., 2)` is deliberate and matches the module: the failure points at
the caller's line. `wc -l < cosmic/check.tl` is 324 today and 347 after —
153 lines of headroom under the 500-line cap.

**2. `cosmic/check_assertions_test.tl` — three tests**, appended at the end
of the file (this file has no trailing `print`), each called on the line
after its `end`, using the file's own `must_fail` helper:
`test_refuses_returns_the_refusal_message` (a local function returning
`nil, "cwd must be a string"`; the helper returns that string),
`test_refuses_throws_when_the_call_succeeds` (returns a value; must throw,
message contains `expected a refusal`), and
`test_refuses_throws_on_an_empty_message` (returns `nil, ""`; same). The
three cover every branch of `refuses`, which is what keeps the coverage
ratchet quiet. `wc -l < cosmic/check_assertions_test.tl` is 426 today and
461 after — 39 lines of headroom left.

**3. `cosmic/quicksand/box/init_test.tl` — three probes, 10 cast lines.**
- `test_new_rejects_bad_types`: delete the `new_any` re-type (line 35) and
  the four fallout casts (lines 47–49); the loop body becomes
  `local err = check.refuses(Box.new, c.opts)` followed by one
  `assert(err:find(c.want, 1, true), ...)`. Retype the cases table from
  `{{string: any}}` to `{Case}` with

  ```teal
  local record Case
    opts: {string: any}
    want: string
  end
  ```

  **declared at FILE SCOPE, above the test function, not inside it.** A
  `local record` nested inside a `test_*` function trips the
  call-after-define lint, which reads the record's `end` as the function's:
  measured 2026-08-25 — an 8-line file whose only content is a `test_*`
  function containing a nested record fails
  `cosmic --check lint <file>` with
  `call-after-define: 'test_nested_record' must be called immediately after
  its definition`, and hoisting the record makes the same file pass. The
  defect itself is captured as board item `3IP9ijhv`; do not fix it here.
- `test_run_requires_argv`: delete the `run_any` re-type (line 57) and both
  fallout casts; the first probe becomes
  `local err = check.refuses(j.run, j, nil)` (the receiver is passed
  explicitly — `refuses` takes a plain function). The second call stays a
  normal `j:run({})` and its error is already typed; rename its locals so
  they do not collide with the first (`local code, err2 = j:run({})`).
- `test_fs_deny_rejected_at_new`: delete the `new_any` re-type (line 129)
  and both fallout casts; both probes become
  `check.refuses(Box.new, ...)`, keeping the two existing assertion
  messages.

Lines 118–121 of this file are NOT touched — see `Non-goals`.

**4. `cosmic/quicksand/box/run_test.tl` — one probe, 2 cast lines.**
`test_bogus_sys_promise_rejected_at_new` becomes
`local err = check.refuses(quicksand.new, {sys = {promises = "stdio bogus_promise"}})`
plus the existing `find("bogus_promise", 1, true)` assertion. The file's
cast count reaches zero, so its row leaves `_build/casts_baseline.tl`
entirely.

**5. `cosmic/surface_test.tl` — two dead casts.** Both narrow nothing
today; verified 2026-08-25 by deleting each and running
`bin/cosmic --check types cosmic/surface_test.tl`, which prints
`Type check passed`:
- line 98 — `require("cosmic.doc") as {string: any}`: the module name is a
  literal, so the searcher resolves the real record and `doc["query"]`
  indexes it directly. Becomes `local doc = require("cosmic.doc")`.
- line 132 — `(mod as {string: any}).internal`: `mod` comes from
  `idx.modules`, declared `{string: ModuleDoc}` (`cosmic/doc/types.tl:62`),
  and `ModuleDoc.internal: boolean` is a declared field
  (`cosmic/doc/types.tl:57`). Becomes `mod.internal == true`.

**6. Four surface probes — relabel the reason, keep the cast.** Each is
live (verified 2026-08-25 by deleting it and running `--check types`), and
each probes a surface the declared type deliberately does not describe.
Replace the trailing `-- cast: from any` with
`-- cast: probe past the declared surface` on:
`cosmic/fd_read_test.tl:109` (calling the `fs.sync_all` value read off a
module-as-map probe; without the cast: `not a function: <any type>`),
`cosmic/fs/find_close_test.tl:87` and `cosmic/sqlite/close_test.tl:62,179`
(reading `__close` off a raw metatable; same error). The cast counts of
these three files do not move; only the reason does. `fd_read_test.tl`
already uses the neighbouring spelling `-- cast: probe module surface` on
lines 107–108; leave those alone — this slice adds one spelling for the
class, it does not unify the existing ones.

**7. `_build/casts_baseline.tl` — regenerate.** Run exactly the command the
gate's failure message prints,
`bin/cosmic --make run _build/casts.tl --baseline`, and commit the result.
Expect `casts: wrote _build/casts_baseline.tl — 363 casts in 119 files`
(today 376). Read the diff before committing: only the five rows named in
`Acceptance` may move. `cosmic/check.tl` RISES from 3 to 4 — that is the
intended trade, one cast inside the helper for the 13 it retires, and the
gate is a per-file ratchet that must be re-baselined for it, never
weakened. The prototype run needed no `.cosmic-coverage` rewrite
(`coverage ratchet ok`); if the coverage gate does ask on the day, run the
command IT prints and commit that too.
