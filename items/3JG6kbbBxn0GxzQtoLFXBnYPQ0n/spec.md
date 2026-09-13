# brief review: pin the diff/script kinds' unmapped-repo fallback with a test

## Change

`review_product_root(s, it, map_only)` (`_work/brief.tl`, landed in #162) keeps
gitboard's own checkout as the fallback root for the diff and script review
kinds when the caller's `gitboard.repository` map cannot place the item's repo,
and its doc claims `REVIEW_SCRIPT`'s `--repo-dir` relies on it. Nothing pins
that: every `brief_review_script_test` handover maps the repo (`handover_diff`
adds `gitboard.repository`), and `brief_test`'s
`test_product_root_fills_from_gitboard_dir` asserts `<PRODUCT_ROOT>` absent on
a full `REVIEW`, which carries no `{{.product_root}}` at all — vacuous. The
#162 review proved it by mutation: flipping the call site to
`review_product_root(s, it, true)` left all 31 brief tests green.

Add one test to `_work/brief_review_script_test.tl`: a script-kind handover
whose repo is NOT in the map, rendered from a checkout that is the product
repo itself, asserting `--repo-dir` names that checkout. Then run the same
mutation and show it red.

## Non-goals

- No behaviour change to `review_product_root`; the fallback stays.
- No change to the research branch, which is already pinned map-only by
  `test_an_unmapped_repo_leaves_the_reproduction_tree_to_the_caller`.
