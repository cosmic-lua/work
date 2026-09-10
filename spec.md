## Current refinement — current renderer literal-data regression

This refinement supersedes the historical ROUND_CONTEXT/`scan_values` mutation below. Current v3 deliberately stores no review prose, initializes `ROUND_CONTEXT` to empty, and has no `scan_values`, so that old input path and mutation no longer exist. Preserve the intended user-visible contract through the current spec-input path instead.

## Evidence

At `ba673e3576f57b4a74ac94f326077abf7e957a62`, `_work/brief.tl` assigns `SPEC = spec`, `ROUND_CONTEXT = ""`, fills the template, then detects missing fields with `survivors(template, values)`. `_work/brieftext.tl` states that the board stores no review prose, and `_work/brief_rework_test.tl` already asserts that a review brief has no provider round context.

`sh o/bootstrap/cosmic --make test _work/brief_rework_test.tl` passes 6/6 on main. A refinement probe using the real fixture/store and a spec containing `Keep <CONST_NAME>, {{.field}}, and <HEAD_SHA> verbatim.` rendered that spec byte-for-byte and ended with `nothing left to fill`. Replacing `local left = survivors(template, values)` in memory with `local left = unfilled(body)` preserved the body but incorrectly ended with `fill <CONST_NAME>, <HEAD_SHA>`, proving a current meaningful mutation.

## Change

Add one regression test to `_work/brief_rework_test.tl`, beside `test_review_brief_has_no_provider_round_context`, named `test_review_brief_preserves_literal_template_tokens_in_spec`.

Use the file's existing `init_state_repo`, `root_with_leaf`, and `handover_item` helpers to create a valid commit handover. Replace that fixture item's spec using the existing imported `storewrite.save`, supplying this exact string as its fourth argument, including the final newline:

```text
## Change
Keep <CONST_NAME>, {{.field}}, and <HEAD_SHA> verbatim.
## Non-goals
Nothing else.
```

Run `brief_and_capture(s, "review", leaf)` inside `with_product_root`, so every genuine placeholder in the full review template has an answer. Assert exit code zero, assert the complete spec string appears unchanged in the rendered output with a literal search, and assert the final printed line contains `nothing left to fill`. Assert against the final line rather than the body, because the body intentionally contains placeholder-shaped data.

`<CONST_NAME>` exercises an unknown uppercase token, `{{.field}}` preserves future typed-template-looking data, and `<HEAD_SHA>` exercises a name the outer review template actually answers. Keep all three assertions together as one public `brief review` regression.

## Non-goals

Do not change production rendering, item storage, verdict formats, or templates. Do not restore stored review prose, provider-derived round history, `scan_values`, or historical ROUND_CONTEXT blanking. Do not add fields or fabricate a stored round-1 review body. Do not undertake the typed-template migration or post to external issues in this change.

## Access

cosmic-lua/work, read and write on a branch; cosmic-lua/cosmic, read-only for the linked typed-template migration context; no other repository.

## Ready when

The new test passes on current main and fails when `_work/brief.tl`'s `local left = survivors(template, values)` is changed to `local left = unfilled(body)`, while confirming the complete spec text remains verbatim and the restored renderer reports `nothing left to fill`.
