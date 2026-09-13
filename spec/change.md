Keep the published bytes, and make the fallback refuse to guess.

1. `bin/cosmic`: save the verified download as `o/bootstrap/cosmic.ape`
   (pristine) and assimilate a COPY into `o/bootstrap/cosmic`. One stamp
   covers both; a pin bump re-downloads both; `--make clean` removes both
   (`_make/clean.tl`).
2. `_make/artifact.tl` `bases_of`: "the running cosmic" resolves to the
   `.ape` sibling of the executable when one exists with a matching stamp;
   otherwise to the executable itself when its first two bytes are `MZ`;
   otherwise the build REFUSES with a message naming the assimilated image,
   that a build onto it would be host-only, and the two ways out (run the
   published release, or declare a base in the unit's generator). A refusal
   is a `nil, string` from `build`, never a throw.
3. Tests, in the same PR: `_make/artifact_test.tl` covers the three
   resolutions (sibling present, MZ executable, refusal) with fixture files;
   `_make/fixtures_test.tl` asserts the `hello` fixture's artifact starts with
   `MZ` when built under the bootstrap (it does not today); `_make/clean_test.tl`
   covers the sibling's removal; any existing test that assumed the fallback
   base is the executable is fixed rather than skipped. `_cli/fence_test.tl`'s
   assimilated-bootstrap assumptions stay true, since the assimilated copy
   still exists.
4. Docs: the `bin/cosmic` header comment and AGENTS.md's trust-root paragraph
   say a pristine copy is kept and why.

After this lands, remove cosmic-lua/work's `3p/cosmic/cosmic_pin.tl` and
`cmd/gitboard/embed_gen.tl` in a follow-up there; the fallback then yields
the same fat artifact.
