The Goal's file list is stale — measured now, it names two files that
no longer carry any cast and omits one that does:

```
$ grep -n -- "-- cast:" _perf/bench/literal_bench.tl _perf/run.tl
(no output — both files carry zero casts today)
$ awk -F'\t' '$3 == "runtime capability probe" {print}' docs/design/cast-sites.tsv
cosmic/quicksand/box/init.tl	90	runtime capability probe
cosmic/sandbox/init.tl	200	runtime capability probe
cosmic/sandbox/init.tl	205	runtime capability probe
cosmic/sandbox/init.tl	220	runtime capability probe
cosmic/sandbox/plan.tl	190	runtime capability probe
cosmic/sandbox/plan.tl	241	runtime capability probe
cosmic/stream.tl	237	runtime capability probe
```

(`_perf/bench/literal_bench.tl` and `_perf/run.tl` were routed through
`cosmic.check.is_exposed` by #1585, which also added
`docs/design/casts.md` and `docs/design/cast-sites.tsv` — the Goal's
numbers predate that PR by three days.) The class today is these 7
sites in 4 files, confirmed against `_build/casts_baseline.tl`:

```
$ grep -n '"cosmic/quicksand/box/init.tl"\|"cosmic/sandbox/init.tl"\|"cosmic/sandbox/plan.tl"\|"cosmic/stream.tl"' _build/casts_baseline.tl
  ["cosmic/quicksand/box/init.tl"] = 1,
  ["cosmic/sandbox/init.tl"] = 3,
  ["cosmic/sandbox/plan.tl"] = 2,
  ["cosmic/stream.tl"] = 1,
```

Of the 7, exactly 3 are the Goal's literal "boolean presence check"
shape — a bare `~= nil` membership test with no read of the value,
each guarding a validator's error path for a field that was removed or
renamed:

```
$ grep -n -- "-- cast:" cosmic/sandbox/init.tl cosmic/quicksand/box/init.tl
cosmic/sandbox/init.tl:200:    if (fs as {string: any}).deny ~= nil then -- cast: record to map probe
cosmic/sandbox/init.tl:205:      local v = (fs as {string: any})[name] -- cast: record to map probe
cosmic/sandbox/init.tl:220:    if (sys as {string: any}).exec ~= nil then -- cast: record to map probe
cosmic/quicksand/box/init.tl:90:    if (proc as {string: any}).pledge ~= nil then -- cast: probe for removed field
```

— lines 200, 220, and quicksand's line 90. The other 4 sites are a
different shape and are OUT OF SCOPE (see Non-goals): line 205 above,
and `cosmic/sandbox/plan.tl:190,241`, all fetch the VALUE by a
dynamically-computed name inside a `for _, name in ipairs({...})` loop
and type-check it — not a boolean presence test — and
`cosmic/stream.tl:237` casts to a whole reader interface
(`r as stream.DelimReader`), not a map probe at all. Routing exactly
the 3 pure-boolean sites through one shared helper is what lands the
class at 5: the 4 untouched sites plus the helper's own single
internal cast.

1. Add `cosmic/_probe.tl` — a new file, internal by the leading
   underscore (`cosmic/doc/visibility.tl`'s rule: public is exactly
   `cosmic.<name>` with no `_`), so it carries no doc-index entry and
   is reachable from any file under `cosmic/`. Precedent for a
   leading-underscore top-level helper shared across unrelated
   `cosmic/*` subsystems: `cosmic/_fields.tl` (used by `cosmic.log`
   and `cosmic.instrument`). It exports one function:

   ```teal
   local function is_present(t: any, name: string): boolean
     -- cast: probe a table for a name its declared type may not carry
     return (t as {string: any})[name] ~= nil
   end
   ```

   Give it a module doc comment (no history, per `docs-style`) and an
   `@param`/`@return` doc comment on `is_present`, matching this
   repo's doc-comment convention. `t: any` means callers pass their
   already-typed record with no cast at the call site — the same move
   `cosmic.check.is_exposed` makes for test code
   (`return (module as {string: any})[name] ~= nil`) — this is that
   shape's library-legal home: `cosmic/check.tl`'s own header says
   "no other cosmic.* module may throw or exit" and, in prose just
   above, "never require check from library code"; `cosmic/sandbox/`
   and `cosmic/quicksand/` are library code, so `check.is_exposed`
   cannot be the shared helper for these 3 sites — this new module can
   be, since it carries none of check's throw-on-failure behavior.

2. `cosmic/sandbox/init.tl`: add `local probe = require("cosmic._probe")`
   beside the file's other `require("cosmic.sandbox.*")` calls
   (currently lines 36-39). Replace line 200's
   `if (fs as {string: any}).deny ~= nil then -- cast: record to map probe`
   with `if probe.is_present(fs, "deny") then` (same body, same
   returned error message — only the test changes). Replace line 220's
   `if (sys as {string: any}).exec ~= nil then -- cast: record to map probe`
   with `if probe.is_present(sys, "exec") then`. Leave line 205
   untouched.

3. `cosmic/quicksand/box/init.tl`: add
   `local probe = require("cosmic._probe")` beside its other requires
   (currently lines 27-29 — `cosmic._probe` has no `cosmic.*`
   dependency of its own, so this cannot join the require cycle the
   file's header comment describes for the fork/exec orchestrator; no
   lazy-require treatment needed). Replace line 90's
   `if (proc as {string: any}).pledge ~= nil then -- cast: probe for removed field`
   with `if probe.is_present(proc, "pledge") then`.

4. Add `cosmic/_probe_test.tl` exercising `is_present`: a record (or
   plain table) with a field present and absent by name, asserting
   `true`/`false`; one case whose `t` is a genuinely typed record
   (e.g. reuse `cosmic.sandbox`'s `Fs` shape or an ad hoc local record)
   passed with no cast at the call site, to exercise exactly the
   library call shape steps 2-3 use.

5. Regenerate the two derived files these edits move:

   ```
   bin/cosmic --make run _build/casts.tl --baseline
   bin/cosmic --make run _build/cast_sites.tl --reconcile
   ```

   The first drops `cosmic/quicksand/box/init.tl` from
   `_build/casts_baseline.tl` entirely (0 casts = absent, per that
   file's own doc comment), lowers `cosmic/sandbox/init.tl`'s row from
   3 to 1, and adds a `["cosmic/_probe.tl"] = 1` row. The second drops
   the 3 rows this reduces and adds one new row for
   `cosmic/_probe.tl`'s internal cast; per `_build/cast_sites.tl`'s own
   doc comment ("a site with no prior row has no class to carry... stays
   committed unclassified until a person edits the row in by hand"),
   hand-set that new row's class column to `runtime capability probe`
   in `docs/design/cast-sites.tsv` — `--reconcile` will not do this for
   you, and `_build/cast_sites_test.tl` gates the committed file
   against a reconciled read, so a row left unclassified fails that
   test. Confirm the class lands at 5:

   ```
   awk -F'\t' '$3 == "runtime capability probe"' docs/design/cast-sites.tsv | wc -l
   ```

   should print `5`. `docs/design/casts.md`'s
   `### runtime capability probe` section already says "five today"
   and its only fenced quote for the class is `cosmic/stream.tl:237`,
   which this change does not touch — no edit needed there once the
   count above reads 5.

6. If `bin/cosmic --make coverage` reports `cosmic/_probe.tl` under its
   implicit floor (a new file starts with no row), add its row to
   `.cosmic-coverage` by hand with the covered/total pair coverage
   reports — do not run `--make coverage --baseline` (AGENTS.md: that
   rewrite is refused outside `COSMIC_COVERAGE_ENV=1`, which only CI's
   `ci` lane sets).
