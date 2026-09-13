In each of the five files, declare a module-level `<const>` Spec beside
the record it validates into and replace the cast sites with one
`shape.into` call.

1. **`_eval/score.tl`** — add `local shape = require("cosmic.shape")`
   and a `META_SPEC` naming the nine required fields with their
   `eval_types.ResultMeta` types (`timestamp` number, `suite_version`
   integer, `bin`/`bin_sha`/`os`/`isa`/`model`/`agent_tool` string,
   `timeout_secs` integer) plus `cosmic_version =
   shape.optional(shape.string)`. `load_meta` becomes
   `return shape.into(raw, META_SPEC)` after the decode. Delete
   `REQUIRED_META_FIELDS` and its loop.

   `into` returns the SAME table, so `load_meta` now yields the decoded
   `meta.json` table rather than a fresh nine-field one. Both leave
   `probe_output` and `leaked` unset — `fold_probe` fills them — and
   nothing iterates the record's keys
   (`grep -n "pairs(meta)" _eval/score.tl` reports nothing), so the
   extra keys a payload may carry are inert. Say so in a comment at the
   Spec.

2. **`_eval/stage.tl`** — the manifest's `surfaces` and `metrics` are
   CSV STRINGS that `split_csv` turns into `{string}`, so the Spec
   validates the raw shape, not `eval_types.Task`. Declare a local
   `record RawTask { id, brief, surfaces, metrics, status: string }` and
   `record RawManifest { version: integer; tasks: {string: RawTask} }`,
   with `surfaces`/`metrics`/`status` optional (today's `rt.surfaces as
   string or ""` admits absence). `load_manifest` validates once into
   `RawManifest`, then builds each `eval_types.Task` from typed reads,
   keeping the existing `tasks[tostring(i)]` walk and the two
   `return nil, path .. ": …"` messages for an empty id and a
   task-less suite.

3. **`_build/size.tl`** — `REPORT_SPEC` mirroring `Report`: `trees =
   shape.map(shape.record({tl_files = shape.integer, lines =
   shape.integer}))`, `agents_md_lines` and `public_modules` integer,
   `binary_bytes = shape.optional(shape.integer)`. `load_report`
   becomes `return shape.into(decoded, REPORT_SPEC)`.

4. **`_perf/baseline.tl`** — `RELEASES_SPEC = shape.list(shape.record({
   tag_name = shape.string, created_at = shape.string, draft =
   shape.boolean, prerelease = shape.boolean, assets =
   shape.list(shape.record({name = shape.string,
   browser_download_url = shape.string})) }))`. Widen `list_releases`
   to `{Release} | nil, string`, update its `@return` comment, and
   `return shape.into(decoded, RELEASES_SPEC)`.

5. **`_perf/compare.tl`** — `RESULTS_SPEC` mirroring
   `perf_types.Results`: `meta` a record of `Meta`'s fields with
   `bin_sha` optional (its own doc says it is absent when the binary
   could not be read), `results` a `shape.list` of `Measurement`'s
   fields with `error` optional (absent on success). Widen
   `load_results` to `pt.Results | nil, string` at `:32` and at `:274`,
   update its `@return` comment, `return shape.into(decoded,
   RESULTS_SPEC)`, and delete the `results.results == nil` check.

Then rewrite the ratchet floor with exactly the command the gate
prints — `bin/cosmic --make run _build/casts.tl --baseline` — and
commit the result. Never hand-edit `_build/casts_baseline.tl`.
