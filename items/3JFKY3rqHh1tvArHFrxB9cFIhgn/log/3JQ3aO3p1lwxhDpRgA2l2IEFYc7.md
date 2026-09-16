At main 8ffb62e0927c8065be63a0f405b09d60af3e0ad3, brief.tl renders
it.claim_base directly and the review templates show two dots. repository_map
already makes paths absolute; the reproduced source-level path gap is its
acceptance and persistence of linked worktree roots. Absolute conversion
alone would preserve the wrong anchor. a65J_xJWz records the take --repo-dir
linked-worktree route even while cwd was a canonical checkout.