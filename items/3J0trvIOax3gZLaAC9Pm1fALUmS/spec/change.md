Fix `3p/tl/tl_patch/narrow_record_field.tl`'s `narrow-record-field-assignment`
hunk so the narrow invalidation happens before the assignment's
expected type is derived, not after. Two viable mechanisms — pick one,
whichever the patch's own hunk structure makes cleaner to express
(read the existing hunk before deciding; do not guess at tl.lua's
internal call order from this description alone):

1. Move the `self:drop_field_narrows(field_key)` call earlier in the
   assignment-checking pipeline — before `vartype`/`vartuple` are
   derived from the LHS expression (e.g. into a `before_exp` hook on
   the assignment node, or wherever `set_expected_types_to_decltuple`
   runs, rather than the current `after` callback).
2. Leave the invalidation timing as-is, but have the LHS-type
   derivation for an assignment TARGET bypass the live narrow fact
   entirely — look up the field's declared type from the record
   definition instead of going through the same `type_check_index`
   path a read uses (a write's expected type should never come from a
   narrow fact, only a read's).

Add a regression test to `3p/tl/tl_patch/` (or wherever the existing
narrow-record-field patch's own tests live — locate them first) using
the minimal repro above: a record with a `T | nil` field, a guard
narrowing it to nil on the fall-through branch, then an assignment of
a non-nil `T` value — asserting this type-checks successfully.
