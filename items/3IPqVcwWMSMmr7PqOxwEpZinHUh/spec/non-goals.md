- **Do not change what any test asserts, with the one exception
  `Change` names and quotes.** The null-policy tests
  (`cosmic/json_test.tl:174`–`:208`) and the nesting and bracket-key
  tests (`cosmic/literal_test.tl:143`–`:145`, `:251`) exist to pin
  behaviour that is deliberately dynamic. No assertion is weakened,
  reworded to a shape it did not have, or deleted because a validator
  made it redundant. The exception is `cosmic/json_test.tl:7` and `:15`,
  where `assert(type(result) == "table", "expected table")` becomes
  `assert(result is {string: any} / {number}, "expected table")` —
  runtime-identical (`is` compiles to that same `type()` test) and
  message-identical. Every other guard is an added line beside an
  untouched assert.
- **Do not touch the sibling slice's six files** (`_eval/score_test.tl`,
  `_eval/stage_test.tl`, `_make/pin_test.tl`,
  `cosmic/teal_config_test.tl`, `_tool/doc/index_test.tl`,
  `cosmic/fetch/verbs_test.tl`).
- **Do not touch `cosmic/json.tl`, `cosmic/literal.tl` or
  `cosmic/shape.tl`.** The `json.decode` contract — what it returns and
  how `null_value` behaves — is frozen for this slice; a test that
  reveals a contract problem files an item, it does not fix it here.
- **Do not add a combinator to `cosmic.shape`.** No site in this slice
  reaches for a Spec at all.
- **Do not swap `decode` for `decode_object`/`decode_array` anywhere in
  `cosmic/json_test.tl`**, for the reason `Change` states: the narrower
  entry points have their own four tests, and a swap would delete this
  file's only coverage of bare `decode`.
- **Do not edit `_build/casts_baseline.tl` by hand**; run the regen
  command the gate prints.
- **Do not weaken a gate**: no `.cosmicignore` entry, no coverage
  exclusion, no lint suppression.
- **Do not touch `whilp/cosmopolitan`.**
