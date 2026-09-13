One file plus its test. `wc -l < _work/gh.tl` is 220;
`wc -l < _work/gh_test.tl` is 62.

1. **`refusal`'s 403 branch names the two-step recovery** instead of
   deferring to a maintainer. It must say, in this order: that the
   merge was refused for the CLIENT rather than for the diff; that the
   accept stands and the item stays in `land`; and that the recovery
   is to merge the request by another route and then re-run
   `gitboard land <id>`, which takes the already-merged path. Keep
   GitHub's own detail verbatim at the end, as it is today. Do not
   name a specific tool for the out-of-band merge — the credential
   that works is a property of the session, not of the board.

2. **Nothing else changes.** `is_merged`, the 409 branch, the generic
   branch and the merge call itself are untouched.

3. **Tests.** `_work/gh_test.tl`'s
   `test_refusal_names_the_permission_wall` currently asserts the
   message contains `ask a maintainer`. Update it to assert the new
   contract instead: that the 403 message names `land` as the
   recovery verb and still ends with GitHub's detail, and that it
   remains distinct from both the 409 and the generic branches.
