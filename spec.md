# Goal

Land and ordinarily release the complete make-startup/dispatcher capability proven for `lmuu_JdtZ`, building it against the already landed API release. This is the second and final release prerequisite; activating the resulting release pin remains parent work.

# Exact implementation

Extract the exact tracked change from proven parent candidate `aa2d7ef2ae6274038a7afa2ac795093445d689b9` on base `ba33269688b4abc2d1c86495b9a97a9b3ec77db1`. The candidate changes only:

- `bin/cosmic.pin` to verified API release `2026-09-09-ba33269`, URL `https://github.com/cosmic-lua/cosmic/releases/download/2026-09-09-ba33269/cosmic-lua`, SHA-256 `15289c59ccead28369c8d5174a3735b9dd981dbb2031e6d6b8d6282a8e627b65`;
- early make selection/root discovery/source-searcher installation and shared root in `cmd/cosmic/main.tl`, `_make/startup.tl`, `_make/init.tl`;
- command-local handler/run loading and compatible independent script loading in `_cli/main_handlers.tl`, `_cli/script.tl`;
- exact pinned-boundary/coldbuild/stamp fixtures, tests, documentation, and AGENTS updates already present in that candidate.

Do not change the landed API implementation/tests, launcher protocol, generic manifest/searcher/cache behavior, release workflow, or unrelated code. Preserve the authoritative parent specification and research addendum.

# Required evidence

- Verify the unchanged wrapper downloads the named API asset and its SHA-256.
- Ordinary cold build under that pin passes.
- Full-source empty-`o/` widened #1775 fixture passes generation 1 under the explicit complete candidate runtime; the fixture wrapper using the API-only pin remains a named failing control at the generator-child eager handler import.
- Pinned-boundary ratchet passes 3/3; focused startup/script/boundary tests pass; all seven required mutations fail for their intended reason and pass after restoration.
- Scoped build/format/types/examples/lint and full supported GitHub build/CI/repro/smoke checks pass.
- Fresh independent exact-head review accepts before auto-merge.

# Landing and release

After review and exact-head GitHub checks, enable auto-merge and require merge-group checks. From the exact landed main commit, dispatch unchanged `release.yml` with `prerelease: false`. Verify the published `cosmic-lua` asset URL and SHA-256. Do not update `bin/cosmic.pin` to that complete release in this child; that activation and wrapper-based widened cold acceptance belong to the parent.

This child is complete only when its code is landed and its ordinary complete-capability release is published and verified.
