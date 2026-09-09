## Evidence

The original report is a real safety problem: PR cosmic-lua/cosmic#1770
changed the committed docs/design/cast-sites.tsv schema from three columns
to five, but its spec described only steady-state reconciliation. The builder
had to invent an uncommitted bridge because existing rows lacked the new keys.
This item makes that migration decision explicit before building; it does not
change a tracking-file generator.

Refinement inspected cosmic-lua/work product commit
cbe7be81e0ef00129b39000256bc2f405fa57041 in the claimed worktree.
`git status --short` was empty. No AGENTS.md or SKILL.md was present:
`rg --files -g AGENTS.md -g SKILL.md` returned no paths.

Measured with:

```
wc -l _work/doctrine.tl _work/doctrine_test.tl _work/brieftext.tl \
  _work/brieftext_test.tl _work/spec.tl _work/spec_test.tl \
  _work/gitready.tl _work/gitboard.tl _work/gittake.tl
```

Output:

```
498 _work/doctrine.tl
236 _work/doctrine_test.tl
392 _work/brieftext.tl
215 _work/brieftext_test.tl
164 _work/spec.tl
136 _work/spec_test.tl
151 _work/gitready.tl
473 _work/gitboard.tl
285 _work/gittake.tl
```

`_work/doctrine_bar.tl` is absent. The obvious split seam is the one
`PAGES` entry beginning at doctrine.tl:154
`{name = "bar", title = "the spec bar: what makes an item pullable",`,
whose literal body occupies lines 156–238. The next entry is "build" at
line 240. These locations were read with
`sed -n '150,242p' _work/doctrine.tl`.
The existing internal pure-data module pattern is
`_work/brieftext_friction.tl` (read with
`sed -n '1,42p' _work/brieftext_friction.tl`): a literal constant,
one-field record, and returned module table. Use that pattern, not a new
public API or generic page registry.

The old spec's automatic-refusal entrypoint is stale. Measured with
`sed -n '408,425p' _work/gitboard.tl` and
`sed -n '221,234p' _work/gitcommands.tl`:
the current CLI declares `take ID --head SHA` and dispatches to
`gittake.take_handover` at gitboard.tl:421. The latter validates the claim,
product-base lineage, and exact head; it does not call the spec bar.
The older `gitverbs.cmd_take` still calls
`gitready.ready_problems` at gitverbs.tl:183, but it is not that CLI branch.
`rg -n 'ready_problems' _work/*.tl` locates the remaining legacy helper,
show diagnostics, and their tests; this item must not move a gate onto
handover or change claim semantics.

The current mechanical grammar only requires a nonempty Change:
`sed -n '58,75p' _work/spec.tl` shows `ready_gaps` iterating
`READY_SECTIONS`, whose sole entry is "Change".
The following read-only probe used the supplied warm compiled module,
whose function matches that source:

```
sh o/bootstrap/cosmic -e 'local spec = dofile("o/_work/spec.lua"); for _, change in ipairs({"Change docs/design/cast-sites.tsv from 3 columns to 5.", "Change docs/design/cast-sites.tsv from 3 columns to 5. Migrate existing rows with a committed rewrite.", "Correct one row in docs/design/cast-sites.tsv without changing its shape.", "Add one entry to _work/example_baseline.tl."}) do print(#spec.ready_gaps("## Change\n" .. change .. "\n") .. " gaps: " .. change) end'
```

Output:

```
0 gaps: Change docs/design/cast-sites.tsv from 3 columns to 5.
0 gaps: Change docs/design/cast-sites.tsv from 3 columns to 5. Migrate existing rows with a committed rewrite.
0 gaps: Correct one row in docs/design/cast-sites.tsv without changing its shape.
0 gaps: Add one entry to _work/example_baseline.tl.
```

A suffix match cannot distinguish the third and fourth cases from a schema
migration. Nor does a keyword such as "migration" establish that existing
rows have an executable route. Inferring arbitrary prose is not a bounded
honest machine check; requiring a new structured declaration would be a new
spec language, not this small policy countermeasure. This refinement therefore
explicitly replaces the old automatic-refusal requirement with caller/builder
enforcement. No machine migration grammar is introduced.

`bin/gitboard help bar` was unavailable on this host (exit 127:
`no such file or directory: bin/gitboard`). The equivalent local read-only
dispatch succeeded:

```
sh o/bootstrap/cosmic -e 'package.path = "o/?.lua;" .. package.path; local gitboard = require("_work.gitboard"); assert(gitboard.main("help", "bar") == 0)'
```

Its output began `bar — the spec bar: what makes an item pullable`,
included the existing "If yes, it is not ready." sentence and the
caller-readiness paragraph, and contained no existing-row migration rule.
The full output was read during refinement. `shasum -a 256 o/bootstrap/cosmic`
matched bin/cosmic.pin:
`b4bb8bde84fc54c4298e4d63d949a1af071d2ff5a2e1ba095fa70d9e342ee434`.
Use that verified runtime via `sh` on this host.

Existing test seams were read with
`sed -n '1,250p' _work/brieftext_test.tl`,
`sed -n '1,236p' _work/doctrine_test.tl`, and
`sed -n '1,136p' _work/spec_test.tl`.
Doctrine tests already capture real help dispatch;
brieftext tests already flatten the literal builder template before matching;
spec tests already exercise ready_gaps directly.
No new fixture framework or test sibling is necessary.

## Change

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

## Non-goals

No machine recognition of tracking-file names, schema changes, or migration
prose; no new structured migration declaration or spec grammar. No change to
take, claim, ready_gaps, ready_problems, handover, verdict, or provider behavior.
No attempt to impose the obsolete legacy pull gate on current commit handover.
No change to any tracking-file generator, no migration of this repository's
tracking data, and no retroactive edits of closed specs. No unrelated doctrine
cleanup, template changes, or module refactoring. No changes outside the
explicit source/test scope except the two narrowly permitted coverage rows.

## Access

cosmic-lua/work, read and write on the claimed branch; no other repository.
