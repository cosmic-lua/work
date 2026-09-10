## Change

Ready when: release `2026-09-10-851d5ec` exists with a `cosmic-lua` asset.

Update only `bin/cosmic.pin` to pin
`https://github.com/cosmic-lua/cosmic/releases/download/2026-09-10-851d5ec/cosmic-lua`
with SHA-256
`10f66af3cfe6b55e3f97c058ddff5e6b0ba3faf6eef8c2462cb7372895e4e1c2`.

Download that exact asset independently, verify its digest, and verify
`--version` reports `2026-09-10-851d5ec`. Run the focused pin/bootstrap tests
named by the repository. Keep the product diff to the existing two data lines
in `bin/cosmic.pin`; comments need no rewrite.

## Non-goals

No CLI activation, parser changes, surface code, build-system changes, release
workflow edits, or additional pin updates. Bounce if the published asset does
not match the tag and digest above.
