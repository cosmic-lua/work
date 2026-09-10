## Evidence

`gitboard worktree --fetch` repeatedly downloaded and hash-verified the pinned Cosmic runtime as `o/bootstrap/cosmic.ape`, then ran `--make build`. Current Cosmic `_build/coldbuild_test.tl` declares `reads: o/bootstrap/cosmic`, so preparation failed before the graph with `o/bootstrap/cosmic does not exist`. Each builder/reviewer required a manual copy from `.ape` to the declared path and a second build/adoption sequence.

Completed `5VQX_QrYT` explicitly required both target candidates, but the landed path still permits the verified `.ape` cache artifact to exist without materializing the repository-declared bootstrap input before build. Treat this as a focused regression against that contract.

## Change

In Cosmic-kind worktree preparation, after verifying/staging the exact pinned runtime and before invoking the product build, materialize the same verified bytes at every supported bootstrap path required by the target repository contract, including `o/bootstrap/cosmic`. Publication must be atomic and no-overwrite-safe; a pre-existing mismatched file refuses, while matching verified bytes are reused. Creation, adoption, and review preparation share the same path.

Add an isolated target fixture whose build refuses unless `o/bootstrap/cosmic` exists and matches the pin. Cover fresh cache miss, cache hit, adoption after a retained failure, and review preparation. Mutate the implementation to publish only `.ape`; the fixture must fail before claiming preparation success.

## Acceptance

One `gitboard worktree --fetch` call reaches a terminal successful build/receipt for a Cosmic repository declaring `o/bootstrap/cosmic`; no manual copy or second bootstrap is needed. Failure diagnostics print a complete retry/adoption command including repository root and canonical retained path.

## Non-goals

No unverified launcher execution, Make-project contract, broad `o/` copying, or new receipt schema.

## Access

`cosmic-lua/work`, read and write on a branch. Tests use fixture runtimes and no real downloads.
