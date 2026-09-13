- **Do not touch `cosmic/json_test.tl` or `cosmic/literal_test.tl`.**
  Their 17 sites are the sibling slice: there the decode is the
  SUBJECT, and replacing `decode` with `decode_object` or validating
  into a record changes what is under test.
- **Do not touch a non-test file.** `3IOeg86u` owns those.
- **Do not change what any of these tests assert.** A narrowing
  `assert(d is …)` may be ADDED — it makes the test stricter — but no
  existing assertion is weakened, reworded to fit a type, or deleted.
- **Do not change `cosmic/shape.tl`**, its test or its example.
- **Do not add a field to `eval_types.Row` or `EvalResults`**, and do
  not make a nullable field non-nullable to simplify a Spec.
- **No new `as` cast and no new `-- cast:` line anywhere in the diff.**
