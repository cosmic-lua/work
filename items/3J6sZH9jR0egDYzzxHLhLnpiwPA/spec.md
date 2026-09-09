## Evidence

The current friction log records the same worktree preparation failure in several forms:

- `gitboard worktree` printed a successful “bootstrapped” verdict after its bootstrap subprocess failed and required artifacts were absent;
- fresh worktrees retried GitHub DNS for roughly 40 seconds before falling back to verified artifacts already present in the orchestrator checkout;
- a warm `o/bootstrap/cosmic` was ignored because its stamp was absent, even when its bytes matched the declared pin;
- on the current macOS host, portable APE artifacts work through `sh <artifact>` but direct execution returns `permission denied`;
- unconditional copying of optional `o/3p` produced a noisy failure when that cache did not exist;
- worktrees did not carry a usable repository-local Git author identity.

`_work/gitworktree.tl` is 360/500 lines and `_work/gitworktree_test.tl` is 499/500, so new coverage cannot be added to the existing test file without a split or a new sibling test file. Related item `HNez_qkM2` covers Cosmic's own stale-bootstrap guard; this item is specifically the gitboard worktree preparation contract.

## Change

Make `gitboard worktree` prepare a checkout from verified local inputs before attempting network acquisition.

1. Discover reusable `o/bootstrap` and `o/3p` inputs from the resolved product checkout. Validate the declared pin artifact by digest and required capabilities, not stamp presence alone. Probe each cache independently and report `reused`, `absent`, or `digest mismatch`; an absent optional dependency cache is informational.
2. Emit and use one canonical runtime invocation for the host (`sh <artifact>` where direct APE execution is unsupported). Do not retry a known-inapplicable assimilation path.
3. Treat checkout creation and bootstrap as separate postconditions. A successful final verdict requires the repo-specific required artifacts to exist and pass their validation; otherwise return a failure verdict that preserves the created checkout path but does not call it bootstrapped.
4. Copy repository-local `user.name` and `user.email` from the resolved product checkout when present, and fail preflight with a precise remedy before handing off a checkout that cannot commit.
5. Add coverage in a new `_work/gitworktree_bootstrap_test.tl` (or split the capped existing test) for cache-first success with network disabled, optional-cache absence, digest mismatch, shell invocation, missing required artifacts, and Git identity propagation.

Coordinate repo-specific bootstrap discovery with `AP77_4XCs`/`oJ31_ppvR`; do not duplicate their general repository-mechanics resolver.

## Non-goals

No credential discovery, no copying unverified build outputs, no change to claim authority, and no requirement that every repository have an `o/3p` cache.

## Access

`cosmic-lua/work`, read and write on a branch; product checkouts are read-only fixture inputs.

## Ready when

With GitHub DNS unavailable but a digest-valid declared pin present in the product checkout, `gitboard worktree` prepares a usable checkout without a network attempt, prints the exact runtime digest and host invocation, and refuses a success verdict whenever required bootstrap artifacts or Git identity are missing.
