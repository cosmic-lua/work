## Evidence

The parent `lmuu_JdtZ` proposed installing the existing Layer-3 tree searcher
after `_make/root.tl` discovers the project root. A controlled root-only
manifest fixture disproves that mechanism: widening `_cli.lint.lint_file` and
its caller still reports `given 2, expects 1` with both the verified pin and
current searcher. `cosmic/searcher.tl`'s tree path calls `compile_cached` with
only `strict`; the compiler cache options have no tree-root include-directory
contract, so selecting a live source file does not make its sibling type
resolution live-tree-first.

The proposed timing is also too late. `_cli.main_handlers` loads from
`cmd/cosmic/main.tl` before argument parsing and root discovery, and `_make.init`
eagerly imports its engine before `open_project`. Those modules cannot be
protected by a searcher installed during the later discovery step.

Evidence logs are in the claimed parent worktree as
`o/lmuu-{plain-from-fixture,tree-check-from-fixture,manifest-from-fixture,current-manifest}.log`.

## Outcome

Define the smallest sufficient design for the parent before production edits:

- identify the earliest reliable point where an invocation is known to be
  `--make`, the project root can be determined, and the searcher can install
  before every module the fix claims to protect;
- define how tree-selected Teal modules compile and cache with the discovered
  root taking precedence for sibling type/source resolution, including the
  cache-key/invalidation consequences;
- name the exact modules necessarily loaded before installation and therefore
  still bounded by the pin;
- preserve ordinary `bin/cosmic some_script.tl` pin-first behavior;
- provide minimal executable fixtures for the protected `--make` widening and
  unchanged ordinary-script behavior.

Return a concrete file/symbol-level change plan and revised parent spec text.
If no make-only installation point can satisfy the boundary without changing
the launcher/bootstrap protocol, state that explicitly and propose the
smallest prerequisite item instead of broadening the parent silently.

## Non-goals

No production edits in this research item. No change to pin contents, fetch,
or ordinary-script resolution. No general searcher or compiler-cache redesign
beyond what the parent's exact Path B fix requires.

## Access

`cosmic-lua/cosmic`, read-only investigation; no other repository.
