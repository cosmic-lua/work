One PR on cosmic-lua/cosmic, pulled only after «Xvox_XNCM» is on main
(`git show origin/main:bin/cosmic.pin | grep url` names a release
whose tag commit contains `8758f80c`):

1. `3p/cosmos/cosmos_pin.tl`: bump `version` and `sha` to the newest
   cosmos release at pickup time, at or after `2026.09.04-65bc139fc`
   (re-verify per Evidence). Then, per AGENTS.md's update procedure:
   `bin/cosmic --make fetch`, `bin/cosmic --make build`,
   `o/bin/cosmic --make ci`. Generation 1 now seeds the declarations
   from this pin (D43), so the closure compile fails on the FIRST
   unadapted closure member with the real error — adapt and re-run.
2. For every file the regenerated types break (the table above is the
   expected set; the build is the authority), change ONLY the
   wrapper's internal destructuring of the `cosmo.*` call to the new
   shape. Each wrapper's own public contract — its Teal signature and
   its documented error behaviour — is unchanged. Where slot 2 is now
   a union (`MkstempPath | string`, `integer | string`), narrow with
   `is` on the success branch; no casts. If a wrapper's contract
   cannot be preserved under the new binding shape, stop and file that
   wrapper as its own item, unparented, with the site quoted, then
   continue with the rest.
3. Run the compare gate against the previous pin per the `optimize`
   skill (`_perf/run.tl` before and after, `_perf/gate.tl compare`),
   as AGENTS.md requires for a cosmos pin bump.

Sizing: ~23 files, ~130 diagnostics, most of them one- or two-line
destructuring edits. It is over the ~400-line smell threshold and is
still one PR: a pin bump is atomic — the tree compiles against exactly
one `definitions.lua` — so there is no file-disjoint split that leaves
each half green.
