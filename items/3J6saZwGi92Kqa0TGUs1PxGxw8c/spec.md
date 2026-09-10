## Change

Implement on main commit 7aefdc66edaea50e77c293952056f6d5d0de8e37.
It descends from this claim's ce5747ff91574594cd59782ecfe8b0ce59da73d1
base: `git merge-base --is-ancestor <claim-base> <main-commit>` exits 0.
The unused claimed branch may fast-forward to that main commit before
editing; preserve the already-landed version-preservation fix
851d5ec655d54353b1fa24a9b5d6d4cbd02c0f47.

Add a required, read-only post-publication verifier to the existing
release workflow. It verifies the published primary asset's bytes and
version against this run's tag, build commit and publication digest.
Commit and digest belong in verification evidence; do not change the
binary's --version format.

Change exactly these three files:

1. `.github/workflows/release.yml`

   Preserve schedule/workflow_dispatch, prerelease selection, concurrency,
   existing build/peers dependencies, and publication assets. Preserve
   `echo "COSMIC_VERSION=$tag" >> "$GITHUB_ENV"` in the naming step and
   the version assertion immediately before artifact upload.

   In `name the release` (`id: tag`), record `git rev-parse HEAD` as the
   full build commit, require it to equal GITHUB_SHA, and expose it as a
   step output and build-job output named `commit`. Continue computing
   the dated tag once. Do not substitute a seven-character tag suffix
   for the full commit identity.

   In the publishing job, pass `needs.build.outputs.commit` through an
   environment variable BUILD_COMMIT. Give `create release` an explicit
   bash shell, `set -euo pipefail`, a step id `publish`, and a job output
   `digest` wired to that step.

   Before publication, inspect the exact remote tag with
   `git ls-remote --refs origin "refs/tags/$TAG"`. A failed remote query
   must fail the step. If the tag exists, fetch that exact tag and require
   `git rev-parse --verify "refs/tags/$TAG^{commit}"` to equal BUILD_COMMIT.
   This handles annotated tags and refuses an existing mismatched tag.
   Leave a missing tag for `gh release create` to create, passing
   `--target "$BUILD_COMMIT"`. Do not overwrite or force-move tags.

   After staging the publication files and generating SHA256SUMS,
   record SHA-256 of the staged `release/cosmic-lua` as the publish step's
   `digest` output. Keep publication in this job; do not execute the
   downloaded release binary under its contents:write permission.

   Add job `verify`, with:
   - `needs: [build, release]`;
   - `runs-on: ubuntu-latest`;
   - `permissions: {contents: read}`;
   - a bounded timeout of 10 minutes;
   - explicit bash and `set -euo pipefail`;
   - TAG, BUILD_COMMIT and EXPECTED_DIGEST environment variables sourced
     from the dependency outputs.

   Do not check out or build the project in this job. In a fresh directory
   under RUNNER_TEMP, fetch the exact public repository tag into an empty
   Git repository with a depth-1 fetch, dereference `FETCH_HEAD^{commit}`,
   and require equality with BUILD_COMMIT. Do not treat a release API
   `target_commitish` field as proof of the tag's resolved commit.

   Download both assets from the final tag-qualified browser paths:
   "$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/releases/download/$TAG/cosmic-lua"
   "$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/releases/download/$TAG/SHA256SUMS"

   Use curl with HTTP failure detection, redirects and bounded retries
   (five retries, two-second delay, 180-second retry ceiling, 60-second
   request timeout). Do not use latest, draft/API asset endpoints, an
   Actions artifact, a local build, or cached asset fallback.

   Select exactly one SHA256SUMS row whose filename is exactly
   `cosmic-lua`, require its digest to be 64 lowercase hexadecimal
   characters, and compare it with EXPECTED_DIGEST. Reject missing or
   duplicate primary rows. Check the downloaded binary using a newly
   constructed checksum line naming only `cosmic-lua`; do not pass the
   unfiltered manifest to sha256sum, because it also names the undownloaded
   debug asset and could name arbitrary local paths.

   Execute the verified APE with `sh ./cosmic-lua --version` on this
   Linux-only job. Do not pass --assimilate or rewrite its bytes.
   Capture output with failure propagation; require one nonempty line,
   first whitespace-delimited field `cosmic-lua`, and second field exactly
   TAG. Comparing that field must reject `unknown`, tag prefixes/suffixes,
   and a tag appearing only in the cosmos version. Recheck the downloaded
   binary's checksum after execution.

   Only after every check passes, emit one evidence line to the log and
   GITHUB_STEP_SUMMARY:
   `release-verify: PASS tag=<tag> commit=<full-sha> sha256=<digest>`

   Keep this a normal required job within release.yml, without job/step
   continue-on-error, mismatch guards that return success, or optional
   event conditions. A failed verifier must make the original release
   workflow run fail, although publication has already occurred.

2. `_build/workflows_test.tl`

   Add exactly the two-line UNCONTAINERISED entry:
   ["release.yml:verify"] =
   "published-asset verification on Linux; no build machinery",

   Preserve the version-preservation test and all existing ratchets.
   Main has 497 lines (`git show <main>:_build/workflows_test.tl | wc -l`);
   this addition brings it to 499, under the 500-line cap.

3. New `_build/release_workflow_test.tl`

   Use runner-enrolled local test_* functions and declare
   `--- reads: .github/workflows/release.yml` before the first local.
   Keep the whole file below 500 lines. Use cosmic.check/cosmic.fs and
   local indentation-aware job/step extraction in the style of the
   existing workflow test; do not add a YAML dependency or public API.
   Avoid casts and nil-returning non-nil signatures, so no new cast or
   nil-return baseline rows are required.

   Scope assertions to active job/step configuration and run bodies;
   comments elsewhere must not satisfy them. Cover:
   - checked-out full commit output and publication --target wiring;
   - existing-tag dereference/equality before publication;
   - publisher digest output and verifier dependency/environment wiring;
   - Linux host, read-only permission and required failure semantics;
   - both tag-qualified browser downloads and bounded failure-aware curl;
   - exactly one primary checksum row, publisher-digest equality, checksum
     checks before and after executing that downloaded path;
   - exact reported-tag equality and evidence after all checks;
   - absence of assimilation, latest URLs and artifact/local-build fallback
     within the verifier.

   Exercise the same structural validator against in-memory mutations
   of the actual workflow: remove release from needs, change verifier to
   contents:write, remove --target, remove commit equality, replace its
   browser path with latest, remove either checksum verification, weaken
   exact tag equality, add continue-on-error, and add --assimilate.
   Each mutation must produce a relevant failure; the unmodified workflow
   must pass. Do not edit the checked-in workflow to run these mutations.

Run the new focused test alongside `_build/workflows_test.tl` and
`cosmic/version_test.tl`, then the repository's normal
`bin/cosmic --make ci` gate. Workflow execution cannot be fully simulated
by structural tests; do not dispatch a release merely to validate this PR.

Measured locations on main, from `git show <main>:<path> | rg -n ...`:
release.yml naming step 80; GITHUB_ENV stamp 89; pre-upload version
assertion 175; release job 259; gh release create 306.
workflows_test.tl UNCONTAINERISED 168; existing release exemption 171;
version-preservation test 484.

## Non-goals

No change to the dated version scheme, CLI version format, debug-asset
verification coverage, release immutability settings, existing published
assets, or unrelated workflows.

A tag-qualified download URL is not itself proof that GitHub enforces
release immutability. This change proves the bytes downloaded during
verification equal this run's publication digest and remain unchanged
during execution. It does not promise that an administrator can never
replace assets later.

A post-publication failure marks the workflow failed; it does not undo
publication. Do not delete, replace, or unpublish a failed release here.
