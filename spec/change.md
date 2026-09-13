Extend `_work/spec.tl`'s ready-bar checks and the generated builder/refinement guidance for changes that name `bin/cosmic.pin`, a pinned bootstrap, or release activation.

Require a `## Staging` section that identifies:

1. the additive or dormant capability that passes the current pin and current release gate;
2. the exact release-producing commit/ref and the gate that can publish it;
3. the pin update that activates the capability;
4. the later consumer commit that becomes admissible only after activation;
5. executable old-pin/new-pin probes demonstrating the intermediate states.

The checker should enforce structure and explicit commands, not attempt to prove arbitrary prose. Add focused fixtures in `_work/spec_test.tl` or a new sibling test file for a valid two-release sequence and for the circular “consumer needed to publish its own prerequisite” shape that must be refused or sent to refinement.
