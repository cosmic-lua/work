`gitboard claim` captures the product base from the local target branch
without checking that branch against its own remote-tracking ref, so a claim
made in a checkout whose `main` is behind `origin/main` silently records a
stale base. `gitboard worktree` then branches the builder's checkout from it,
and nothing in either verb's output says so.

`gitboard claim --help` already documents the intended behaviour:

    --fetch-base  when the product repository's local target branch is behind
                  its own configured remote-tracking ref, fetch that remote and
                  fast-forward the branch before capturing the claim base;
                  otherwise such a claim refuses

The refusal does not fire. Make it fire.

Where the product repository is the board repository itself, `_work/product.tl`
special-cases it as `BOARD_REPO`; check whether that path bypasses the
behind-check, and make the board repository no exception either way.

Add to `worktree`'s verdict line the base commit it branched from, so a
builder can tell a stale checkout from a stale spec without archaeology.
