Implement only the migration-planning doctrine and generated builder guidance
below. The enforcement points are the caller's pre-build spec review and the
builder's existing stop-and-request-refinement workflow. Tests enforce that
the tool emits these instructions; they do not claim to semantically validate
arbitrary future migrations. The old "take refuses" requirement and its
missing-migration machine fixture are intentionally retired.

1. Extract only the existing bar literal from `_work/doctrine.tl` to a new
   internal `_work/doctrine_bar.tl`. Follow brieftext_friction's pure-data
   pattern: constant BODY, record doctrine_bar with BODY: string, returned
   module table. Require it from doctrine.tl and replace that one PAGES
   entry's literal value with doctrine_bar.BODY. Keep the page's name,
   title, ordering, all other page bodies, and the exported doctrine API
   unchanged. The moved bar body is byte-for-byte unchanged except for the
   following insertion immediately after "If yes, it is not ready." and
   before "Measured, not inferred:" (with paragraph separation):

   ```
   A `## Change` that alters the shape of a committed tracking file
   (a TSV, a baseline `.tl`, or a `.cosmic-*` floor) states how its
   existing rows reach the new shape: a first-run migration the
   change performs, an exact one-off command, or a rewrite committed
   with the change.
   The caller checks this before building; a missing plan means stop
   and refine the spec, not invent a bridge.
   ```

   This is the sole new doctrine policy. Preserve normal hand-wrapping;
   do not squash existing prose into long lines to fit the cap. The
   self-contained literal extraction is the explicitly authorized,
   low-risk cap seam, not a broader module reorganization.

2. Append this instruction to builder step 2 in
   `_work/brieftext.tl`, immediately after its existing
   "scope; hold every `## Non-goals` wall." sentence:

   ```
   When `## Change` alters a committed tracking file's shape, follow
   its migration plan and commit the migrated file with the change;
   name the first-run or one-off bridge, if any, in your final report
   for the caller's PR body. If the plan is absent, STOP and request
   refinement before editing the tracking file.
   ```

   Indent consistently with step 2. Do not instruct a builder to open a
   PR or perform board operations. This conditional instruction does not
   demand migrations for ordinary row maintenance. The caller transfers
   the reported bridge into a PR body if a PR is used; the committed
   migration must not depend on a provider operation.
   Every other literal template, including RESEARCH and both review
   templates, is frozen. Do not change selectors or filling behavior.

3. Add `test_bar_requires_an_existing_row_migration_plan` to
   `_work/doctrine_test.tl`. Use its existing
   gitboard_and_capture("help", "bar") helper and assert exit zero.
   Match the complete new paragraph after whitespace flattening, including
   all three file examples, the three migration routes, caller ownership,
   and stop/refine rather than inventing a bridge. Do not replace or weaken
   existing page/dispatch tests.

4. Add `test_builder_requires_a_committed_migration_and_caller_report`
   to `_work/brieftext_test.tl`. Match the entire new builder instruction
   against its existing flattened BUILDER constant. The test must pin the
   migrated-file commit, bridge report for the caller's PR body, and
   pre-edit STOP/refinement behavior, not merely the word "migration".
   Preserve all existing caller-owned-operation assertions.

5. Add `test_tracking_file_mentions_do_not_add_a_machine_migration_grammar`
   to `_work/spec_test.tl`. Table-drive the four exact Change bodies in
   the evidence probe; assert ready_gaps remains empty for each.
   This compatibility test makes the explicitly narrowed scope durable:
   it does not assert these specs are semantically ready to build, only
   that the existing syntax checker does not invent a filename/keyword
   migration classifier. Do not edit `_work/spec.tl` or its consumers.

6. Scope is exactly the five existing source/test files above plus the new
   `_work/doctrine_bar.tl`: doctrine.tl, brieftext.tl, doctrine_test.tl,
   brieftext_test.tl, spec_test.tl, and doctrine_bar.tl. Every file stays
   at or below 500 lines. No new fixture, cast, nullable-return signature,
   public cosmic module, CLI flag, or board field is needed.

   The only potentially affected coverage entries are the existing
   `["_work/doctrine.tl"]` row and the new
   `["_work/doctrine_bar.tl"]` row. The current doctrine row is 41/41,
   measured by `rg -n -F '["_work/doctrine.tl"]' .cosmic-coverage`.
   If the extraction requires baseline maintenance, edit only those
   named rows from measured coverage; do not weaken retained coverage
   or regenerate the entire floor. No other baseline movement is
   authorized. README.md:252–268 explains that the board CI job owns
   whole-floor recording and a private-clone baseline rewrite is unsafe.

7. After extracting the required sibling, run the normal build once before
   type-checking dependent files. Run scoped type/format/lint checks and
   all three affected test files; run coverage after the final test edit,
   then full CI. Use `sh o/bootstrap/cosmic` in place of bin/cosmic on this
   host without altering the pin or bootstrap source.

   Commit the real change before mutation testing. Independently replace
   the complete new doctrine paragraph and then the complete new builder
   instruction with unrelated text, and prove the respective named test
   fails each time. Restore exactly and rerun all three focused test files.
   These are instruction-regression mutations, not evidence of a new
   runtime migration gate.
