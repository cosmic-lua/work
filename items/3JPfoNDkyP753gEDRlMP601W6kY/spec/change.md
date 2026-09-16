Add verified, per-user machine-wide storage of pristine pinned cosmic bytes
for worktree preparation, and let this repository's bin/cosmic launcher reuse
those bytes without a second download. The current source/target bootstrap
cache already works without --fetch. Preserve PR184's explicit --fetch
contract: it forces runtime acquisition even when cached bytes are usable.

Use an absolute XDG_CACHE_HOME when supplied, otherwise an absolute HOME
plus /.cache; below that use cosmic/runtime/<pin-sha256>/cosmic.ape. With no
usable absolute cache base, retain source/target-only preparation and report
that shared caching is unavailable. Do not reinterpret a relative path
against cwd. The cache key and expected bytes come from the target's existing
validated committed pin, never a stamp, filename, source pin or runtime claim.
Store pristine bytes only; native assimilation remains launcher-local.

Preserve the existing target/source lookup order in worktree_runtime.prepare,
then try the shared entry before ordinary acquisition. Reuse the same regular,
non-symlink, size-bounded actual-byte digest checks and private execution
snapshot discipline. A rejected entry is diagnosed and never executed; a
miss or rejected entry may acquire normally. Publish verified pristine bytes
into the shared entry after ordinary or forced acquisition or a verified
local hit, so a second unrelated checkout can reuse them. Never execute the
mutable shared file directly. Keep rechecks before bootstrap steps and final
success, dependency-fetch behavior and receipt authority unchanged.

Use exclusive complete-file publication, not overwrite: create a private
same-directory temporary, write and rehash its bytes, then hard-link to the
final entry and unlink this invocation's temporary. Refuse symlink or
non-directory cache ancestors within the selected cache path. Never replace
or delete an existing final entry. Validate an existing/concurrent winner;
report an invalid winner and continue with the separately verified private
runtime without claiming cache publication succeeded. Other publication or
cleanup failures are explicit preparation errors. Do not share generated
outputs, dependencies or an assimilated execution file through this cache.

Update work's bin/cosmic cold-bootstrap path to try its existing pristine
bootstrap .ape and the shared raw cache before downloading. Copy a candidate
into its private temporary first, then validate that snapshot against the
launcher's own pin before assimilation/execution. Reject symlink/nonregular,
oversized and digest-mismatched candidates. Preserve the launcher's existing
native-ELF conversion of a copy, pristine .ape output, tree-binary preference,
and ordinary invocation arguments. A stamp alone must not admit a new shared
or raw candidate. Do not change the existing hot native-bootstrap contract.
Downloaded pristine bytes may seed the same shared cache using the same
no-overwrite and revalidation semantics. Do not stamp raw APE as native ELF.

Add isolated regressions using fixture-owned digest pins and harmless runtime
stubs, with acquisition intercepted rather than real network. Cover two
unrelated checkouts with the same pin sharing one ordinary acquisition; a
changed pin using a distinct entry; corrupt, symlink and oversized entries;
a concurrent valid and invalid publication winner remaining untouched;
--fetch acquiring despite a valid shared entry; and preparation followed by
the actual work launcher with no o/bin/cosmic and downloads refused, proving
reuse plus pristine/native representation separation. Retain existing
runtime, bootstrap-path and adoption regression behavior. Isolate and restore
environment variables and mocks; never write test entries into the real user
cache. Mutate a digest guard and a reuse guard separately and require named
assertion failures, then restore. Split small focused helpers/tests when
needed to keep files within the repository's 500-line cap.
