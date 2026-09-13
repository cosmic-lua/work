Resolved open question (probed 2026-08-27): `--check types
--include-dir .` under an old release binary resolves modules from
the TREE ahead of its embedded copies — a scratch root shadowing
`cosmic.literal` with a new API type-checks, and a scratch
`cosmic.zzprobe` absent from the zip resolves. So
`o/bootstrap/cosmic --check types --include-dir . --include-dir
o/_types/types_gen <files>` is exactly generation 1's semantics:
pinned tl + pinned patch set, tree module resolution. Validated both
directions on today's tree (539 files, ~15s wall, one process):
- bootstrap afad5b5: exit 0.
- the 08-23 release binary: refuses `_cli/build/init_test.tl:73:14
  "cannot index key 'match' ... string | nil"` — byte-identical to
  PR #1416's cold-build failure — and `cosmic/coverage/init.tl:131`
  (pack-n, the #1423 change that waited for the narrow-pack-n pin).

1. `_build/coldbuild_test.tl` — one test, skew_test's shape: collect
   every `*.tl` under the twelve source trees (3p _build _cli _docs
   _eval _fuzz _make _perf _tool _types cmd cosmic), skip
   `testdata/`, one `--check types` child under `o/bootstrap/cosmic`
   with both include dirs and `COSMIC_COVERAGE=0`; assert bootstrap
   and `o/_types/types_gen` exist (loud, never skip). Failure message
   names the rule and the remedy (stage the change behind a release
   + pin bump, or drop the new-checker dependence). `--- reads:`
   those trees + `o/bootstrap/cosmic` + `o/_types/types_gen`, so a
   source-only diff and a pin bump both invalidate the cached PASS.
2. AGENTS.md, Build System section: a short paragraph stating the
   rule tree-wide (generation 1 compiles the WHOLE tree under the
   pin; a change needing the tree's own checker or patches stages
   behind a release and pin bump) and naming the guard test.
