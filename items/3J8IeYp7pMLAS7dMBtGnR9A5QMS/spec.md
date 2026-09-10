## Change

Ready when: release `2026-09-10-6a9f47c` exists with a `cosmic-lua` asset.

Update only `bin/cosmic.pin` to pin
`https://github.com/cosmic-lua/cosmic/releases/download/2026-09-10-6a9f47c/cosmic-lua`
with SHA-256
`b185791b80cadefad96ca276ce6cad5aa16d72722f385a9d2cb12ee104696a26`.

Download that exact asset independently, verify its digest, and verify
`--version` reports `2026-09-10-6a9f47c`. Run the focused pin/bootstrap tests
named by the repository. Keep the product diff to the existing two data lines
in `bin/cosmic.pin`; comments need no rewrite.

## Non-goals

No CLI activation, parser changes, surface code, build-system changes, release
workflow edits, or additional pin updates. Bounce if the published asset does
not match the tag and digest above.
