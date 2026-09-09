## Evidence

Board item `1ND6_Eum9` was migrated without a target, then repaired with
`gitboard set 1ND6_Eum9 --repo cosmic-lua/cosmic --base main`. `show` and the
item's `meta` both report `target: cosmic-lua/cosmic@main`, and the supplied
product checkout has `refs/heads/main` at
`9c943d131e2c96706bf9e217b3ee9bb69e70905f`. Nevertheless, two acquisitions
after confirmed refreshes recorded `claim base:
b7367648921a110852fe04d856ff13cbd3cf4084`, the item's own historical board
commit. `gitboard worktree` then refused because that board commit is correctly
absent from the Cosmic product repository. Moving the disposable board cache
aside and rebuilding it from remote refs did not change the result.

This makes a repaired target look correct in `show` while claim acquisition
still behaves as if the repository were empty, creating an unusable product
base and blocking the item.

## Change

Make claim product-base resolution use the same normalized target fields that
`show`, `set`, and worktree repository resolution use. Add an end-to-end test:
start with a repo-less migrated item, repair it with `set --repo ... --base
main`, refresh/reopen the store, claim with `--repo-dir` pointing at a product
repository whose main commit is distinct from the item commit, and assert the
claim batch stores the product main SHA and `worktree` starts from it.

## Non-goals

No change to repo-less board-only items; those should continue using their item
commit as the claim base. No fallback that imports a board commit into a product
repository or silently resets a worktree after creation.

## Access

cosmic-lua/work, read and write on a branch; no other repository.
