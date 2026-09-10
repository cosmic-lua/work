## Change

Ready when: release `2026-09-10-6a9f47c`'s `cosmic-lua` asset has SHA-256
`b185791b80cadefad96ca276ce6cad5aa16d72722f385a9d2cb12ee104696a26`
but reports `cosmic-lua unknown` from `--version`.

Change only `.github/workflows/release.yml` and `_build/workflows_test.tl` so
the release candidate keeps `COSMIC_VERSION=${{ steps.tag.outputs.tag }}`
through every build-capable step before artifact upload, especially the
`o/bin/cosmic --make ci` convergence gate that currently rebuilds the binary
without the stamp. Verify the post-gate artifact says the computed tag before
it is uploaded. Add a focused workflow ratchet that fails if the gate can
again rebuild without the release version or if no post-gate assertion protects
the uploaded artifact.

Keep `_build/workflows_test.tl` below 500 lines and the combined changed-line
count at or below 30. Run its focused test. The corrected workflow must be
manually dispatchable on current `main` to publish a replacement release; do
not invent or hard-code the next tag.

## Non-goals

No build-system, embed generator, CLI, surface, pin, release asset, or other
workflow changes. Do not edit or delete the already published bad release.
Bounce if the fix requires a third file or more than 30 changed lines.
