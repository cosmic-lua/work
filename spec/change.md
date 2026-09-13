Split at the nil-flow seam, into the sibling shape
`teal_closure_test.tl` already established:

New `cosmic/teal_nilflow_test.tl` takes the tests that pin how nil
FLOWS (value position and admission), measured at main after #1439:
- test_or_fallback_drops_nil (267-296)
- test_disjunctive_guard_narrows (301-328)
- test_and_operand_narrows_in_value_position (333-359)
- test_nil_union_is_admitted_outside_an_index (369-397)
- test_nil_union_is_refused_at_an_index (402-415)
about 150 lines plus its own header — the header states the file's
scope (nil in value position, and what the checker admits versus
refuses at an index) and points back to teal_narrowing_test.tl for
the guard rules. Tests move byte-identical, calls staying on the
line after each end.

`teal_narrowing_test.tl` keeps the guard and dispatch rules
(truthiness/typevar/boolean/any basics, the is-guard family,
error-terminated and non-return exits, pack-n, metatable
is-dispatch), landing near 335 lines.

The seam is chosen FOR the queue: 3IPXRRd2 (strict nil-flow mode,
the sixth patch group) is the next narrowing item behind the cap,
and its tests are nil-flow tests — the new file is their home, with
~350 lines of headroom, while guard-rule growth keeps ~165 in the
original.
