## Evidence

Two independent sessions in the same /work pass (2026-09-05) hit the same trap
while working item `nG3p_QYHj` (a `3p/tl/tl_patch/narrow.tl` entry):

1. A refiner verifying a scratch patch idea: after reverting the patch entry from
   `3p/tl/tl_patch/narrow.tl`, `o/3p/tl/tl.lua` (the fetched/unpacked build artifact)
   still carried the scratch edit — invisible to `git status` since `o/` is
   gitignored. Required `rm -rf o/3p/tl` + refetch + rebuild (3 extra commands,
   ~1 minute) to actually purge it before the "clean revert" claim was true.

2. A reviewer mutation-testing the shipped patch: removed the `narrow-pcall-zero-return`
   entry and reran `--make test`, expecting the canary test to fail. It PASSED
   instead — a false pass — because the incremental build reused the
   already-patched `o/3p/tl/tl.lua` rather than regenerating it from the pin; the
   generated artifact's staleness wasn't detected on this code path. Only a full
   `rm -rf o/3p/tl o/bin o/.groups o/_types` + refetch forced genuine regeneration,
   which then correctly caught the mutation.

An older ended item, `aBAb_ePPu`, already names this exact failure mode
("Forgetting `--make fetch`. The patch is DATA; editing `3p/tl/tl_patch/...` alone
changes nothing until fetch re-applies it") — so this is a THIRD independent
occurrence of the same class of mistake, not a one-off. In all three cases the
symptom is identical: editing or reverting a `3p/tl/tl_patch/*.tl` entry does not,
by itself, invalidate the corresponding unpacked-and-patched artifact under `o/`;
only a full `rm -rf` of the unpacked target plus a refetch forces re-application,
and nothing in `AGENTS.md` states this.

## Change

`AGENTS.md`'s "versioned deps" bullet (under "Build System" → key concepts) gets
one added sentence documenting the verified incantation for forcing a patched 3p
target to be genuinely re-derived from its pin: `rm -rf o/3p/<name>` (e.g.
`o/3p/tl`) followed by `bin/cosmic --make fetch`, needed whenever verifying that a
`3p/*/tl_patch/*.tl` edit (add, change, or revert) actually took effect — a plain
`--make build`/`--make test` silently reuses the already-unpacked, already-patched
artifact and will not detect the source change on its own.

## Non-goals

Not adding a new verb or flag to `_make` — this item is the documentation fix only,
scoped to recording the incantation that already works, verified twice this pass.
Whether a `--force`-style flag should exist to avoid the manual `rm -rf` is a
separate design question, not opened here.
