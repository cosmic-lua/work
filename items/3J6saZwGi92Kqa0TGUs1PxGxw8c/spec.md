## Evidence

During the staged release for `lmuu_JdtZ`, a downloaded API-stage release asset matched the expected release digest and tag commit but printed `cosmic-lua unknown` for `--version`. The release workflow verifies the build-stage artifact before publication, but does not establish that the asset fetched back through the published release path reports the exact tag.

An asset with ambiguous embedded version metadata weakens pin and incident evidence: digest proves which bytes were fetched, but `--version` no longer independently identifies what those bytes claim to be.

## Change

Extend `.github/workflows/release.yml` with a post-publication verification job or step that:

1. downloads the just-published `cosmic-lua` and `SHA256SUMS` assets through the same release URL consumers use;
2. verifies the asset digest against `SHA256SUMS`;
3. runs the downloaded asset using the host-appropriate invocation and asserts `--version` contains the exact release tag;
4. verifies the tag resolves to the build commit recorded by the workflow;
5. emits the tag, commit, and digest as concise release evidence and fails the workflow on any mismatch or `unknown` version.

Add workflow-structure coverage in a new `_build/release_workflow_test.tl`; `_build/workflows_test.tl` is already 483/500 and should not absorb the new battery.

## Non-goals

No change to the date-based version scheme, no rewriting already published releases, and no reliance on mutable `latest` during verification.

## Access

`cosmic-lua/cosmic`, read and write on a branch; GitHub release assets created by the workflow are read for verification.

## Ready when

A release run is not green unless the immutable asset downloaded from its final release URL matches `SHA256SUMS`, identifies the exact tag through `--version`, and the tag resolves to the workflow's build commit.
