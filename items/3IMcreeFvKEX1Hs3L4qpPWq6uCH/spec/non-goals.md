- **Do not touch `cosmic/sqlite/zipfile_example.tl` or
  `docs/guides/artifacts.md`.** The example is the documentation and
  already gates read/insert/delete through `--make ci`'s `example`
  stage; this file pins what the example does not assert, and
  duplicating its output-matching assertions is the surplus a reviewer
  should cut.
- **Do not re-test what `## Evidence` lists the example as gating.**
  No member-count test, no insert/run/delete round trip: both are
  `Example_inspect_members`, `Example_add_member` and
  `Example_remove_member` restated in a second gated file. If the
  three functions in `## Change` feel thin, that is the slice being
  the least thing, not a gap.
- **Do not assert any member count, file size, or byte total.** They
  are properties of a particular build (641 members and 10,380,538
  bytes here), not of the contract.
- **Do not edit the artifact the test is running from.** Every write
  goes to an `fs.copy` under `TEST_TMPDIR`; a program that rewrites
  the zip it is executing from will fail.
- **Do not change anything in `whilp/cosmopolitan`.** This slice adds a
  test that observes the existing registration; it does not move it,
  rename it, or add a binding. The `cosmo.*` C boundary and
  `tool/net/definitions.lua` are frozen here.
- **Do not touch `cosmic/sqlite/*.tl` sources**, any other
  `cosmic/sqlite/*_test.tl`, `.cosmic-coverage`, or
  `_build/casts_baseline.tl`. `git diff --name-only main` must name
  exactly one file.
- **Do not add a `--docs` entry, a guide, or a new `cosmic.*` module.**
  No public surface moves, so `_build/public_surface_baseline.tl` stays
  as committed.
- **Do not use `cosmo.*` directly.** AGENTS.md restricts raw bindings to
  library internals; a test uses `cosmic.*`.
