# Goal

Stage and release the additive make-root searcher/compiler API required by `lmuu_JdtZ`, without installing or consuming it during startup. This breaks the immutable-pin cycle while keeping the normal PR and release gates unchanged.

# Exact scope

Extract from proven parent candidate `db03124a25a3e6d4b0f6ede09b0bf72ded4f06c9` only the production changes in:

- `cosmic/searcher.tl`
- `cosmic/_searcher_make.tl`
- `cosmic/_teal_engine.tl`
- `cosmic/_teal_project.tl`

Include the focused unit tests for the new make-root loader and project compile context (`cosmic/_searcher_make_test.tl`, `cosmic/_teal_project_test.tl`) and only directly required test registration/coverage declarations. Do not include startup dispatch, `_make`, `_cli`, cold-boundary ratchet, docs, launcher, workflow, manifest, or pin changes.

The public API is additive and dormant: `cosmic.searcher.install_make_root(root)` must not be called by the tree at this stage. The make-only loader is source-first, ignores implicit `o/`, falls through to the binary only for absent tree modules, fails loudly for present broken source, retains an exception-safe reentrancy guard, and compiles strictly without persistent compiled-code reuse. Its narrowly scoped project compile context creates fresh type environments, resolves the absolute root before generated declarations/defaults/user `TL_PATH`, is nesting- and exception-safe, and does not change normal compilation/searcher/cache behavior.

# Required evidence

- Focused positive tests for stale-`o/` exclusion, present-broken-source failure, same-process sibling invalidation, two-root isolation, conflicting `TL_PATH`, guard/context restoration, and unchanged normal behavior.
- Each relevant mutation fails for its intended reason and passes after restoration.
- Cold build the API-only tree under the unchanged verified current pin; the original `_build/coldbuild_test.tl` must pass unchanged. Prior scratch evidence: 653 files and 2/2 ratchet checks.
- Run scoped format/type/lint/tests and full supported GitHub checks.
- Fresh independent review of the exact head.

# Landing and activation

Land this child first. After GitHub checks and review accept it, enable automerge. From the resulting exact main commit, dispatch the repository's ordinary non-prerelease `release.yml`; do not bypass or weaken its gate. Verify the published release asset and SHA-256, then update `bin/cosmic.pin` in the parent work so the full startup consumer can build against this API. This child is complete only when its code is landed and its ordinary release is published and verified; the pin bump belongs to the parent.
