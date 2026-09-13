Per site, in this order of preference: delete a redundant cast, change
the call so the type arrives typed, validate into a declared record, or
narrow with `is`. Never leave a cast whose reason is still `from any`.

1. **`_eval/score_test.tl`** — declare a `RESULTS_SPEC` in the test
   mirroring `eval_types.EvalResults`, with every field `Row` documents
   as nullable in v1 marked `shape.optional`. Change `read_results`
   (`:37-40`) to return `eval_types.EvalResults`:

   ```text
   local results: eval_types.EvalResults =
     check.must(shape.into(check.must(json.decode_object(body)), RESULTS_SPEC))
   ```

   Then delete all 12 casts: the downstream `results.rows`,
   `results.meta`, `row.task` and `row.silent_bugs` reads become
   ordinary typed reads. Put the Spec in the TEST, not in
   `_eval/eval_types.tl`: that module is types-only, score.tl
   constructs the record rather than parsing it, and nothing else in
   the tree reads results.json.

2. **`_eval/stage_test.tl`** — `:77` and `:95` switch to
   `json.decode_object`; `:96` (`meta.bin_sha as string`) copies the
   field to a local and narrows it with `assert(sha is string, …)`.

3. **`_make/pin_test.tl`**, **`cosmic/teal_config_test.tl`**,
   **`_tool/doc/index_test.tl`**, **`cosmic/fetch/verbs_test.tl`** — one
   or two sites each. Use `is` narrowing where the read is one level
   deep, and a compact Spec where it is not. `_tool/doc/index_test.tl`'s
   `decoded_modules` helper is the single funnel for that file, so
   whatever it becomes fixes the file.

Then rewrite the ratchet floor with exactly the command the gate
prints — `bin/cosmic --make run _build/casts.tl --baseline` — and
commit the result. Never hand-edit `_build/casts_baseline.tl`.
