## Evidence

`lmuu_JdtZ` named a release and pin activation dependency, but a completed candidate then failed the old-pin ratchet run by `release.yml` itself. The release workflow therefore could not publish the capability in the form first specified. Discovering the cycle required a second strict bounce and three staging probes after implementation.

This is a recurring bootstrap class: code used by the current immutable pin cannot consume a new API until a release carries it, while the release candidate must still pass gates under the old pin. Existing specs commonly say “stage behind a release and pin bump” without proving that the intermediate release is buildable and publishable.

## Change

Extend `_work/spec.tl`'s ready-bar checks and the generated builder/refinement guidance for changes that name `bin/cosmic.pin`, a pinned bootstrap, or release activation.

Require a `## Staging` section that identifies:

1. the additive or dormant capability that passes the current pin and current release gate;
2. the exact release-producing commit/ref and the gate that can publish it;
3. the pin update that activates the capability;
4. the later consumer commit that becomes admissible only after activation;
5. executable old-pin/new-pin probes demonstrating the intermediate states.

The checker should enforce structure and explicit commands, not attempt to prove arbitrary prose. Add focused fixtures in `_work/spec_test.tl` or a new sibling test file for a valid two-release sequence and for the circular “consumer needed to publish its own prerequisite” shape that must be refused or sent to refinement.

## Non-goals

No permanent release-gate exemption, no automatic release dispatch, and no claim that every pin change needs two releases. Changes that do not alter bootstrap-reachable behavior remain unaffected.

## Access

`cosmic-lua/work`, read and write on a branch; no other repository.

## Ready when

A staged-bootstrap item cannot become pullable merely by mentioning a future release: it carries a concrete, non-circular release graph whose intermediate commit passes the current pin and whose activation and consumer phases are separately testable.
