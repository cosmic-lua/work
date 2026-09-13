In each of the six files, replace the cast sites with one
`shape.into` call behind a helper whose declared return type is the
record being validated into. Add `local shape = require("cosmic.shape")`
to each file that does not already require it.

1. **`_eval/score_test.tl`** (12 sites) — two readers, because the file
   has both kinds of test.

   Declare two module-level `<const>` Specs and keep the existing
   `read_results` name for the strict one:

   - `RESULTS` = `shape.record({meta = META, rows = shape.list(ROW),
     verdict = shape.string})`, where `META` and `ROW` mirror
     `eval_types.ResultMeta` and `eval_types.Row` field for field, with
     the nine nullable fields named in `Evidence` wrapped in
     `shape.optional`. `read_results(path: string):
     eval_types.EvalResults | nil, string` reads the file, calls
     `json.decode_object`, and returns `shape.into(raw, RESULTS)`.
   - `RAW_RESULTS` = `shape.record({meta = shape.map(shape.any), rows =
     shape.list(shape.map(shape.any)), verdict = shape.string})`
     validated into a file-local `record RawResults` with fields
     `meta: {string: any}`, `rows: {{string: any}}`, `verdict: string`.
     `read_results_object(path: string): RawResults | nil, string` is
     the second reader.

   Callers become `local results = check.must(read_results(out))` — no
   annotation needed, per the probe. `read_results_object` is used by
   `test_every_meta_field_is_present` and
   `test_every_row_field_is_present` and by nothing else; every other
   test uses `read_results`. Then delete each cast: `results.rows`,
   `results.meta`, `row.silent_bugs`, `found.silent_bugs` and
   `row.task` are all typed reads under whichever reader that test
   holds, and `by_task` is declared `{string: eval_types.Row}`.

2. **`_eval/stage_test.tl`** (3 sites) — the same two-reader split, one
   test each. Add a `META` Spec mirroring `eval_types.Meta`'s ten
   fields (`cosmic_version` optional) and a
   `read_meta(path: string): eval_types.Meta | nil, string`, used by
   `test_bin_sha_matches_independent_digest` (`:92`) so `meta.bin_sha`
   is a `string` and `#sha` compiles; and a map-shaped
   `read_meta_object` for `test_meta_json_has_all_ten_fields` (`:75`),
   whose presence walk stays exactly as written.

3. **`_make/pin_test.tl`** (2 sites) — declare
   `record Platform sha: string end` and
   `record ExtractedPin platforms: {string: Platform} end` local to the
   file, with `PIN <const> = shape.record({platforms =
   shape.map(shape.record({sha = shape.string}))})`, and read
   `check.must(shape.into(got, PIN))` into a local declared
   `ExtractedPin | nil, string` in `test_extracts_a_literal`. The three
   assertions above it (`got.url`, `got.version`, ...) read
   `{string: any}` off `ext`'s own return and are untouched.

4. **`cosmic/teal_config_test.tl`** (2 sites) — declare
   `record TlConfig gen_target: string; gen_compat: string;
   include_dir: {string} end` and `CONFIG <const> =
   shape.record({gen_target = shape.string, gen_compat = shape.string,
   include_dir = shape.list(shape.string)})`. Bind `local raw = chunk()`
   first — `chunk` is `loadfile`'s `function(...: any): any...` and
   passing the call directly into `shape.into` would carry its whole
   return tuple — then validate. `cfg.include_dir` becomes a typed
   `{string}` and the `ipairs` below it is unchanged.

5. **`_tool/doc/index_test.tl`** (1 site) — `decoded_modules` keeps its
   signature and body becomes a `shape.into(data, INDEX)` where
   `INDEX <const> = shape.record({modules = shape.map(MODULE_DOC)})` and
   `MODULE_DOC` mirrors the existing `ModuleDoc` record. Reword the
   helper's doc comment: it no longer says the cast is kept "here so
   every test below reads a `{string: ModuleDoc}` without repeating it",
   because there is no cast.

6. **`cosmic/fetch/verbs_test.tl`** (1 site) — in `test_result_json`,
   declare `record JsonBody answer: integer end` and
   `BODY <const> = shape.record({answer = shape.integer})`, bind
   `local body, berr: JsonBody | nil, string = shape.into(v, BODY)`,
   assert on it, and delete the bare `-- cast: from any` comment line
   above the assertion.

Then run `bin/cosmic --make run _build/casts.tl --baseline` — the exact
command the gate's failure prints — and commit the rewritten
`_build/casts_baseline.tl`, in which all six rows are gone.
