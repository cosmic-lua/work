## Evidence

The friction log records three identity failures in the preparation handoff:

- `brief` emitted a human-readable `build-<handle>-<suffix>` value while `claim` accepted only a minted 32-hex session;
- claim output labeled a 40-hex board fact as `claim=...`, which was mistaken for the product base because no `product-base=` field was printed;
- the generated brief's branch, worktree, product root, and `bin/gitboard` command disagreed with the checkout and invocation actually created by `gitboard worktree`.

The ambiguity stopped builders before editing and forced the orchestrator to reconstruct authority from several prose outputs. Completed items `RxN2_253n`, `F6zo_pi1N`, `8stN_P3q1`, and `TE1u_Un2i` cover earlier protocol generations but do not cover the current claim-batch/work-branch shape.

## Change

Define one structured preparation receipt shared by `claim`, `worktree`, and `brief`.

1. Name distinct values explicitly: `session=`, `claim-fact=`, `product-base=`, `branch=`, `worktree=`, `runtime=`, and `runtime-sha256=`. A board commit must never be labeled as a claim base or product commit.
2. `worktree` consumes the confirmed claim record and emits the actual created values. `brief` reads those recorded values rather than independently deriving a branch, path, or executable layout.
3. The generated brief includes the exact gitboard invocation/product root that successfully produced it and the exact host-specific runtime invocation established by worktree preparation.
4. Add a machine-readable form using the board's eventual shared structured-output schema; until that schema lands, provide one stable line-oriented receipt with escaping rules and tests. Coordinate rather than duplicate `RSTv_DYmH`.
5. Add an end-to-end fixture covering `session -> claim -> confirmed record -> worktree -> brief`, asserting value identity across every stage and refusing a mismatched or unconfirmed claim.

The implementation may expose a `prepare` convenience verb only if it preserves the existing rule that a remotely confirmed claim is required before product work begins; it must not describe an unconfirmed local batch as authority.

## Non-goals

No weakening of claim leases, no hidden Git push/fetch, no credential brokering, and no change to product branch naming beyond making one authoritative producer.

## Access

`cosmic-lua/work`, read and write on a branch; no other repository.

## Ready when

A caller can prepare a claimed item without parsing narrative output, and the builder brief's session, claim fact, product base, branch, checkout, runtime digest, and executable command are byte-for-byte the values confirmed or created by the preceding commands.
