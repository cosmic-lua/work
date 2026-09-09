# Proposed replacement specification: lmuu_JdtZ

## Evidence and activation dependency

At base 0887935e2e072b0fffe52508a6115003f22eacc6, project-root discovery
is too late to protect dispatcher modules. cmd/cosmic/main.tl requires
_cli.main_handlers at line 44, parses at line 51, and dispatches make
at lines 166-171. handle_make requires _make at _cli/main_handlers.tl:403;
_make/init.tl imports its engine at lines 14-36 before open_project calls
root.discover at line 49. A late searcher cannot replace package.loaded.

The verified 2026-09-07-2b2002d pin loads _cli.main_handlers, _cli.parse,
_make, _make.root, and cosmic.searcher from /zip/*.lua. Editing the same
tree files does not change the first cold invocation of this immutable
binary. A future binary can implement the following design without
changing bin/cosmic's launcher protocol; the existing pin cannot acquire
it without being replaced.

DEPENDENCY: ship the make-startup capability in a release and activate
that release via a separately authorized bin/cosmic.pin bump before
claiming the original cold-bootstrap acceptance condition. Do not change
the launcher, rewrite the pinned executable, clear package.loaded, or
silently call a rebuilt binary the old pin. If pin activation remains
out of scope with no prerequisite, the parent's cold-bootstrap outcome
is blocked, not implemented by a late install.

## Change: make-only startup

1. In cmd/cosmic/main.tl defer _cli.main_handlers and _cli.run until
   after the make-startup boundary. Keep the existing --modules startup
   channel and ordinary zip/runtime searchers intact. Prefer also
   deferring require-hints installation until after this boundary, so
   error-path hint imports cannot enlarge the necessary prefix.

2. Use _cli.parse.parse_args once; do not invent a second raw argv
   recognizer. Apply the existing embed/output/extract environment
   fallbacks before deciding which command wins. A small, pure startup
   predicate must match the existing dispatch precedence, not merely
   test whether opts.make_verb is set. Its exclude set is:
   error; version/help/welcome; compile/compile_strict; nonempty
   format/fix; check_kind; find_pattern/rewrite_pattern; nonempty embed;
   extract; examples ~= nil; benchmark; docs ~= nil; test_argv;
   report_paths; coverage_report_paths; recipe ~= nil.
   Retain current combined-file-command refusal behavior. A selected
   make-help needs no project: do not install for it. An already
   installed explicit --modules manifest keeps its existing semantics;
   this new path applies to top-level make without that manifest.

3. Put this orchestration in a new small _make/startup.tl; it may load
   the pinned _make.root and call discover only after effective make
   selection. Do not require _make.init/the engine to classify make.
   Root discovery means today's semantics: cwd, COSMIC_MAKE_ROOT,
   ambiguous/non-project/unnameable-root guards; no upward root choice.
   Resolve/store an absolute root without chdir: _make.init.run must
   still resolve its own binary and COSMIC_MAKE before changing cwd.
   Discovery failure must preserve existing error precedence (unknown
   verb/help/refusal), not eagerly replace it with a new root error.
   On successful discovery share the selected root with open_project,
   avoiding a second independently chosen root. No output directory or
   manifest file needs to be written just to install the searcher.

4. Add cosmic.searcher.install_make_root(root), an additive exact
   one-argument entry point. Keep implementation in a flat internal
   cosmic/_searcher_make.tl if needed for the current 498-line cap;
   main calls the public searcher, not a cosmic-internal module.
   Install after successful discovery but before handlers/run/engine.
   Idempotent for the same root; refuse conflicting root installation
   rather than silently retargeting a running process. Leave ordinary
   install(), install_manifest(), and install_argv_manifest() unchanged.

## Change: root-aware source compilation, not stale build reuse

The existing manifest searcher is NOT suitable unchanged: it trusts
o/<module>.lua before source, although a top-level pre-graph o/ can be
stale, and its fallback calls compile_cached(path,{strict=true}) without
root includes. CacheOptions currently exposes only strict.

The make-only mode must resolve project source first, with no reads
from the implicit o/ mirror or an inherited closure. Handle the same
canonical flat/init source shapes the project supports. A missing tree
module falls through to the binary; a present broken module fails
loudly and must not silently fall back. Retain the reentrancy guard
while compiling, so compiler internals resolve from the binary, not
recursively through themselves. Reset the guard on every error path.

Use the existing strict compile_file path and its checked output,
with werror=false (warnings belong to the gate). Do not extend the
persistent compile_cached API for this item. The make-startup compile
mode is explicitly UNCACHED across loads/processes: Lua package.loaded
still supplies normal one-load-per-module semantics, but neither a
persistent Lua-code entry nor an unverified built file can stand in
for a type check.

There is also an in-process cache: cosmic/_teal_engine.tl:162,225-250
reuses environments by option/path key. A new narrowly scoped internal
cosmic/_teal_project.tl context, used only by the make source loader,
must tell the engine to construct a fresh environment for this mode.
Root-aware calls must neither consume nor publish env_cache entries.
No change to normal compile/check/cache behavior. Context restoration
must be exception-safe and nesting-safe; no global environment edit.

Within that context assemble the type search path with absolute root
FIRST, then its o/_types/types_gen, then the existing explicit/default
fallbacks and user TL_PATH. Today assemble_tl_path prepends TL_PATH even
ahead of caller includes, so passing include_dirs alone is insufficient
to guarantee this ordering. Do not change TL_PATH precedence outside
the make-only context. Fresh environments also avoid retaining early
pin declaration resolutions after generators create tree declarations.

This deliberately has no new cache key: the new mode bypasses both
persisted compiled-code caching and the type-environment cache. Any
future optimization must key root/configuration and all relevant
sibling/declaration inputs; it is not part of this item.

## Exact pinned boundary and ratchet

The earliest reliable install is AFTER the existing parser has selected
make and root.discover has succeeded, but BEFORE importing handlers,
run, or _make.init. The necessarily pinned Lua module prefix when
reusing current root discovery is the following measured closure,
plus the new startup and installer/context helpers themselves:

_cli.args, _cli.parse;
_make.imports, _make.project, _make.root, _make.types, _make.validate;
cosmic.searcher;
cosmic.flags, cosmic.flags.command, cosmic.flags.getopt,
cosmic.flags.parse, cosmic.flags.types;
cosmic.errno, cosmic.fd, cosmic.fs, cosmic.fs.dir, cosmic.fs.file,
cosmic.fs.find, cosmic.fs.octal, cosmic.fs.ops, cosmic.fs.path,
cosmic.fs.tree, cosmic.fs.types, cosmic.fs.walk, cosmic.proc,
cosmic.proc.rusage, cosmic.stream.

The dispatcher entry/wrapper and native Lua/cosmo runtime are also
pinned. Do not describe only _make.root as the boundary. Protect this
enumeration with an isolated fresh-startup module-load probe; accidental
new eager imports must fail that test and require an explicit boundary
update. The list above was independently reproduced under the pin and
the current built binary, excluding preexisting CLI loads in the probe.

The compiler is a second pinned capsule, not an accidental tree import:
cosmic.teal, cosmic._teal_engine, cosmic._teal_hints, tl, and the strict
compile helpers cosmic._teal_ast, cosmic._teal_discard,
cosmic._teal_types (plus the fs closure already above). Load/freeze
these on the pinned side or retain a guarded load with an equivalent
explicit boundary test. Format source-load failures without optional
hint expansion, so _teal_symptoms is not an unbounded error-path import.
Do not let the new context/helper recursively acquire a tree compiler.

Update AGENTS.md in place: explicit graph/closure compile paths are
tree-aware; make startup becomes tree-aware only after this prefix and
only with a runtime carrying the capability. Pin/compiler/new-flag
staging constraints still exist. Ordinary script resolution is unchanged.

Retain _build/coldbuild_test.tl. Keep whole-tree checking with the pinned
checker, but replace the all-siblings-pin-first approximation with an
overlay containing ONLY the pinned boundary's source snapshots, then
the live tree, then generated declarations. Check the whole source set
against that overlay, because post-install consumers may still call a
pinned boundary module. Keep the guard explicitly conservative where
the simulation over-approximates actual paths. Do not call a failed
overlay check proof that every real cold build fails. Retain GxC2's
historical reproduction record; mark any superseded invariant as such.

## Required executable proofs

1. Root/type seam: a scratch _cli/lint.tl with lint_file(path, limit?),
   plus a new caller.tl passing two arguments. Existing root-only
   manifest fails with given 2/expects 1; make-only root-aware loading
   passes. Removing root-aware compilation must fail this test.
2. Real startup: a temporary full source fixture with both _cli.lint
   declaration/interface and its _cli.main_handlers caller widened
   like #1775. Run the capability-carrying runtime's --make build with
   no compiled o/ (only independently verified fetched pins/runtime).
   The original verified runtime is the failing control; the new one
   must reach/finish generation 1. After release/pin activation, repeat
   using the real bin/cosmic wrapper. Do not substitute warm convergence.
3. Early installation: a tree handler sentinel must run for selected
   make; disabling/moving install after handlers must fail. Parser/root
   sentinels remain pin-backed and are covered by the boundary guard.
4. Ordinary script in the same root: debug.getinfo on a pin-shipped
   required function remains /zip, even with tree/o shadows. Test
   script --make build and -- script --make build, --make=build,
   --make build -- paths, --version --make build, environment embed
   precedence, explicit --modules, make help, unknown verbs, root
   refusals, and COSMIC_MAKE_ROOT from another cwd.
5. Cache/freshness: old o/_cli/*.lua must not hide changed source;
   same caller bytes with only sibling/declaration edits must be
   rechecked on the next process AND next root-aware compile within
   one process. Two roots, same module names and shared normal cache,
   must not contaminate one another. A conflicting TL_PATH copy must
   not win in make mode; ordinary compilation keeps its old precedence.
6. Mutation controls: remove early install; remove root precedence;
   enable strict-cache/build-dir reuse; reuse a prior type environment.
   Each relevant fixture must fail for its specific reason, then pass
   after restoration. Run scoped type/fmt/lint/tests, coldbuild ratchet,
   full coverage/CI, and real cold build in the supported Linux lane.

## Non-goals

No launcher rewrite, package.loaded reset/reload, ambient search-path
export, fetch change, generic manifest behavior change, normal cache
redesign, new ADR, or claim that the unchanged old pin acquired new
startup behavior. Pin activation is a separately authorized prerequisite.
