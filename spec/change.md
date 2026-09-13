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
