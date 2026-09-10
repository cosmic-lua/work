## Evidence

For `1PxG_xw8c`, the saved Cosmic checkout was on another branch and local `main` remained at `ce5747ff` while fetched `origin/main` was newer. `gitboard claim --execute --repo-dir ...` captured the stale local `main`. The unused work branch safely fast-forwarded before editing, and `take` accepted the descendant. After GitHub merge-queue squash `34620a7f`, `done --landed` refused: squash comparison defined the accepted patch as stale-claim-base..accepted, including unrelated intervening main work. All three delivered files were byte-identical between accepted and landed commits, yet even `--force --landed` could not record the real merge SHA; completion required force-without-landed.

The next item avoided recurrence only by dropping its unused claim, manually advancing local `main` to `origin/main`, and reclaiming.

## Change

Make claim-base capture and landed verification agree. For an explicit product repository and target branch, detect when the local target ref is behind its configured remote-tracking ref. Provide an explicit authorized path that fetches/fast-forwards the target before claim publication, and otherwise refuse with the exact commands needed; never silently capture a known-stale base.

Also make `take` record the actual implementation parent/base when the handed-off branch contains a clean fast-forward from the claim base before item edits, or make `done` derive the item patch without treating unrelated base advances as authored work. Preserve exact-byte squash/rebase verification. An audited `--force --landed SHA` repair must be able to retain the real landed SHA after explicit equivalence evidence instead of requiring it to be omitted.

Add an isolated history: claim at A, remote target advances A->B with unrelated files, builder fast-forwards to B and commits item C, provider squashes C onto later target D. Normal completion must accept the squash and record its SHA; a squash missing or changing one item byte must refuse.

## Acceptance

The normal claim/take/done path cannot create the stale-base contradiction, and audited repair never discards a supplied real landed commit. No provider API is trusted as commit evidence.

## Non-goals

No implicit network access without an explicit execution/fetch flag, automatic product merge, or weakening of ancestry/content verification.

## Access

`cosmic-lua/work`, read and write on a branch. Tests use isolated Git repositories and remotes.
