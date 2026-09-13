- No change to the cosmopolitan-side accessors themselves — this
  item only consumes `value_type`/`column_type`, landed by
  `3If5s4hN`.
- No change to how NULL, INTEGER, or FLOAT columns are represented —
  only BLOB gains a distinct type.
- No UDF-registration changes beyond wrapping argument values that
  already flow through the existing UDF-arg push path.
