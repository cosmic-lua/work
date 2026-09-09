# Goal

Define and prove the smallest extension that lets `lmuu_JdtZ`'s make-only tree searcher protect explicit-manifest generator children during the first cold build, without changing ordinary script resolution or broadly making manifest loading tree-first.

# Blocking evidence

Both the verified old pin and the capability candidate fail the required full-source, empty-`o/` #1775 fixture during `_types/tlast_gen.tl` generation. The candidate passes top-level startup, but the generator child runs with `--modules o/_types/tlast_gen.modules`; that explicit manifest omits `_cli.main_handlers.tl`. Frozen manifest fallback compiles the handler without project-root sibling includes, resolves the pinned one-argument `_cli.lint`, and rejects the widened two-argument caller. Candidate trace reaches `/zip/main.lua:71` and tree `require_hints`/handler; old pin imports the handler at `main.lua:44`. Logs are in the parent worktree at `o/lmuu-cold-{old-2,candidate}/cold-build.log`.

# Work

Trace the generator-child command and manifest construction end to end. Compare at least: deferring dispatcher imports until the selected explicit-manifest command actually needs them; carrying the required dispatcher closure in generator manifests; and a narrowly root-aware manifest source fallback activated only for make-owned generator children. Reject options that alter user-supplied `--modules`, ordinary scripts, launcher behavior, or broad manifest/cache semantics.

Produce executable positive and negative probes using the full-source empty-`o/` #1775 fixture. State the exact module/load boundary, root provenance, cache/type-environment behavior, and release/pin staging consequences. Return a concrete replacement patch to the parent specification and a smallest implementation recommendation. Do not make production edits, commit, push, release, or run gitboard workflow verbs.
