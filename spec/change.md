Make claim product-base resolution use the same normalized target fields that
`show`, `set`, and worktree repository resolution use. Add an end-to-end test:
start with a repo-less migrated item, repair it with `set --repo ... --base
main`, refresh/reopen the store, claim with `--repo-dir` pointing at a product
repository whose main commit is distinct from the item commit, and assert the
claim batch stores the product main SHA and `worktree` starts from it.
