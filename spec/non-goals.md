- **Do not change any decode call.** Not the function
  (`decode` stays `decode`), not its arguments, not its `opts`. The call
  is the subject under test; changing it is the one thing that would
  make this diff worthless.
- **Do not weaken or delete a null-policy or nesting assertion.**
  `json_test.tl:174-208` and `literal_test.tl:143-145` are the reason
  this slice exists as its own item.
- **Do not touch any file outside these two.** `3IOeg86u` owns the
  non-test sites, and the sibling test slice owns the other six test
  files — including `_eval/score_test.tl`, which uses a validating
  decode rather than `is`.
- **Do not introduce `cosmic.shape` here.** Validating into a record is
  precisely the mechanism these sites reject.
- **No new `as` cast and no new `-- cast:` line anywhere in the diff.**
  A site that genuinely cannot be narrowed is a finding: leave it, and
  file a capture naming it.
