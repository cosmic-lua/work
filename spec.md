## Change

Add the filesystem prerequisite for the `--make` writer lock: an internal, nonblocking, generation-safe directory claim in `_make/lockdir.tl`, with deterministic tests in `_make/lockdir_test.tl`. Do not activate a build lock in this item. Its caller will still need a separately resolved writer-lifetime protocol before it may reclaim a dead holder.

The storage protocol is a nonempty directory, atomically published at the caller's absolute lock path. Every generation has a fresh `cosmic.uuid.v4()` token and exactly one regular file named `owner-<token>`, containing an opaque payload. Construct that directory privately beside the destination, fully write and close the owner file, and only then rename the candidate directory to the lock path. A nonempty destination is contention. An empty destination left between retirement and directory removal may be replaced. Never publish an empty candidate, overwrite a nonempty destination, recursively remove the lock path, or decide that an owner is dead. The candidate and destination must share one existing parent directory. This primitive does not create that parent or use a temporary directory on another filesystem.

Expose these exact operations and types from the internal module:

- `Claim` has `state` (`"owned"`, `"busy"`, or `"error"`), `token: string`, and `message: string`. `try_acquire(path: string, payload: string): Claim` generates a token itself; only `owned` returns a nonempty token. Empty paths, relative paths, and payloads over 4096 bytes are errors before mutation. Empty payloads are valid. Use an absolute normalized path and one fresh candidate per call; no polling, sleeping, environment reads, or process probes.
- `Observation` has `state` (`"present"`, `"vacant"`, `"changed"`, or `"error"`), `token: string`, `payload: string`, and `message: string`. `observe(path: string): Observation` returns the sole valid owner file and its payload; a missing or empty directory is `vacant`. A generation changing while it is read is `changed`, so the eventual caller can retry. Recheck the filename set after reading; do not combine one generation's token with another generation's payload. Symlinks, non-directory lock paths, invalid owner filenames, multiple owner files, non-regular owner entries, oversized payloads, and other unexpected entries are `error`, preserved on disk. Do not follow an owner-entry symlink.
- `retire(path: string, token: string): boolean, string` validates the UUID token syntax, removes only `owner-<token>`, and then attempts an empty-directory removal. The token names one generation; the function must never remove any other owner's file. An already absent token is success without touching other entries. After removing the named token, an absent directory or `ENOTEMPTY` from a successor is success. Other removal failures are reported. An invalid token performs no filesystem mutation. This operation means "the caller authorizes retirement of this observed generation"; it supplies no liveness guarantee.

Use existing `cosmic.fs` operations and `cosmic.uuid`; keep raw binding calls out of tests. `fs.move` is suitable only because candidates are siblings on the same filesystem: its documented EXDEV copy fallback must never become a publication path. Clean up only the private candidate that this call created after a failed publication. Report a cleanup error as `error`, even when publication originally lost contention. A process killed before publication can leave a private candidate; ignore unrelated candidates and do not add a sweep. A killed creator must never leave a published lock with incomplete owner data.

Keep the result records total: empty strings in fields not used by their state; no nil assertions, casts, or new nil-return ratchet debt. These new files need no entries in `_build/nil_returns_baseline.tl` or `_build/casts_kinds.tl`: introduce zero dishonest nil returns and zero casts. Each file remains below 500 lines. Aim for roughly 200 implementation lines and 200 test lines; this is a single filesystem mechanism, not a make lifecycle refactor.

The tests must make these bounds and races executable:

- Publish/read/retire round trip, the 4096-byte payload boundary and 4097-byte refusal, invalid token/path refusals, and preservation of malformed/symlink/non-directory destinations.
- Construct a private empty candidate while a different published owner exists; demonstrate that no public operation exposes the private candidate as the lock. Exercise a failed publication and verify its private candidate is removed, while the current lock and other unrelated sibling entries remain byte-identical.
- Two real cosmic children contend on one scratch lock path. Coordinate them with explicit ready/go/result files. Release neither winner until both children have reported an acquisition result; exactly one must report `owned`, the other `busy`. After retirement, the loser can acquire. Each child has a 5-second monotonic deadline and is stopped/reaped in a protected cleanup path. No build, network, fixed sleep used as evidence of ordering, or production test-only environment variable is needed. Polling may sleep up to 10 ms between checking barriers; timeout is failure, never a passing outcome.
- Deterministically reproduce two stale observers: both observe generation A; observer 1 retires A; B acquires; observer 2 retires its old A token. B's token and payload must remain unchanged. Separately leave an empty old directory and publish B over it, then run a late empty-directory cleanup attempt and prove B survives. This test must fail if retirement is mutated to recursive removal or an unconditional unlink/removal of the shared path.
- A claim at another absolute lock path remains independent. A process exits after claiming; its on-disk generation remains present. There is deliberately no PID/age reclamation hidden in this module.

Use the normal top-level `test_*` enrollment. Obtain the built cosmic through `TEST_BIN`, and use `cosmic.child` with explicit cwd and bounded waits as existing process tests do. Mark any copied fixture input with `--- reads:`. Fixtures written inline under `TEST_TMPDIR` need no new committed testdata project. The focused check is `bin/cosmic --make test _make/lockdir_test.tl`; the common completion gate remains `bin/cosmic --make ci`. Do not edit workflow files or add another acceptance gate.

Measured at `6a9f47c9f6a8b7db7583b5913d6ff6f487371956` on 2026-09-10 (`git rev-parse HEAD`; `git status --short` printed no changes). `rg -n 'move|temp_dir|remove_dir' cosmic/fs/init.tl` places `remove_dir` at 111, `move` at 132, and `temp_dir` at 163. `rg -n 'local function move|unix.rename' cosmic/fs/ops.tl` printed `126:local function move(oldpath: string, newpath: string): boolean, string` and `127:  local ok, err, eno = unix.rename(oldpath, newpath, unix.AT_FDCWD, unix.AT_FDCWD)`. Lines 131–142 show EXDEV falling back to copy and unlink. `rg -n 'local function v4' cosmic/uuid.tl` printed `13:local function v4(): string`. `cat _build/casts.tl` includes `_make` in `TREES`; `_build/nil_returns_test.tl:15` describes its subject as `return nil` under a non-nil signature, not correctly admitted failure returns.

The directory publication/retirement behavior was measured with this disposable macOS probe, using the available cached runtime (SHA-256 `b4bb8bde84fc54c4298e4d63d949a1af071d2ff5a2e1ba095fa70d9e342ee434`), not claimed as an execution of the current source tree or its different pin:

```sh
sh /Users/wcm/Documents/Codex/2026-09-08/ok-now-that-we-ve-cleaned/board/o/bootstrap/cosmic /dev/stdin <<'LUA'
local u=require('cosmo.unix')
local f=require('cosmic.fs')
local r=assert(f.temp_dir('/tmp/make-publish-probe.XXXXXX'))
local p,a,b=f.join(r,'.make.lock'),f.join(r,'a'),f.join(r,'b')
assert(f.make_dirs(a));assert(f.make_dirs(b))
assert(f.write(f.join(a,'owner-A'),'A'));assert(f.write(f.join(b,'owner-B'),'B'))
print('publish-a',u.rename(a,p,u.AT_FDCWD,u.AT_FDCWD))
print('publish-b-while-a-present',u.rename(b,p,u.AT_FDCWD,u.AT_FDCWD))
assert(f.remove(f.join(p,'owner-A')))
print('publish-b-over-empty-old-generation',u.rename(b,p,u.AT_FDCWD,u.AT_FDCWD))
print('late-reaper-remove-old-owner',f.remove(f.join(p,'owner-A')))
print('late-reaper-rmdir',f.remove_dir(p))
print('successor-survives',f.read(f.join(p,'owner-B')))
assert(f.remove_all(r))
LUA
```

Observed output (the generated temporary path is abbreviated here):

```text
publish-a true
publish-b-while-a-present nil rename: ENOTEMPTY: Directory not empty 39
publish-b-over-empty-old-generation true
late-reaper-remove-old-owner false remove: <scratch>/.make.lock/owner-A: ENOENT: No such file or directory
late-reaper-rmdir false remove_dir: <scratch>/.make.lock: ENOTEMPTY: Directory not empty
successor-survives B
```

## Non-goals

No `--make` entry integration, convergence handoff, wait timeout, PID/PGID liveness policy, stale-age fallback, process-group changes, clean behavior changes, public `cosmic.*` API, C binding addition, or automatic removal of unknown files. In particular, this primitive does not make the parent writer-lock item ready: it solves safe publication and retirement, not the lifetime of all writers. Local-filesystem rename semantics are the boundary; network filesystem locking and hostile external replacement of lock directories are outside this item.
