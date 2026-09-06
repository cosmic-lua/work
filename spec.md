## Evidence

PR cosmic#1774's reviewer measured `_tool/doc/signature.tl`'s `record_function_name` (lines ~126–145) against the old text extractor's regex on a two-level owner chain: dot form `M.Sub.bar` → old kept `"M.Sub.bar"`, new strips to `"Sub.bar"`; colon form `M.Sub:baz` → old stripped to `"Sub:baz"`, new keeps `"M.Sub:baz"`. Its doc comment claims it "mirrors the old text extractor's own rule exactly … whatever its own depth". `test_record_function_name_qualification` in `_tool/doc/signature_test.tl` covers one level only. No two-level chain exists in the tree today (the index diff at #1774 showed nothing outside its three expected groups), so no doc page moved.

## Change

Settle one naming rule for a nested owner chain and state it in `record_function_name`'s doc comment: the rendered name is the full dotted owner chain plus the method (`M.Sub.bar`, `M.Sub:baz`), the same for both forms. `_tool/doc/signature_test.tl` gains a two-level fixture for each form asserting that rendering; the one-level cases stay.

## Non-goals

No change to one-level naming; no change to what pages the index renders today.

## Access

cosmic-lua/cosmic, read and write on a branch; no other repository.

## Ready when

`_tool/doc/signature_test.tl` asserts `M.Sub.bar` and `M.Sub:baz` for the two nested fixtures and passes, and the doc comment names the rule.
