A checkout bootstrapped exactly as gitboard's own refusal instructs can read the
board but cannot write to it, and the refusal that says so is 130KB of ref
names.

Format 6 stores the board on `refs/heads/state` (`gitboard help native`:
"Native format 6 stores the board on refs/heads/state"), and the marker refusal
tells a fresh checkout to fetch exactly two refspecs —
`+refs/heads/state:refs/remotes/origin/state` and
`+refs/heads/board/format:refs/remotes/origin/board/format`
(`grep -n 'local argv = {"git", "fetch", "--atomic", remote,' _work/format.tl`).
After that fetch reads work: `bin/gitboard show --todo 0` rendered all 245 todo
rows. Every write verb then refuses. Measured:

    bin/gitboard new "..." --parent c70t_COiw --repo cosmic-lua/work --spec-file spec.md
    gitboard-new: invalid final board: archive: removed refs/heads/board/seq; archive: removed refs/heads/claim-batches/0035212ab5...

129.8KB of output naming 1,991 refs:

    725 archive: removed refs/heads/items
    723 archive: removed refs/heads/ended
    542 archive: removed refs/heads/claim-batches
      1 archive: removed refs/heads/board (board/seq)

`bin/gitboard snapshot --check` refuses identically with nothing staged, so this
is the checkout's condition, not a bad composition. Fetching the legacy
namespaces resolves it — `git fetch --atomic origin '+refs/heads/*:refs/remotes/origin/*'`
took 6.6s and grew `.git` from 26M to 63M, after which `snapshot --check`
prints `gitboard-snapshot: valid final board`.

The cause is in `problems` in `_work/migrate6_archive.tl`
(`grep -n 'if actual\[ref\] == nil then out\[#out + 1\] = "archive: removed " .. ref' _work/migrate6_archive.tl`).
It compares the durable witness against locally fetched refs and emits one line
per witness ref with no local counterpart. A clone that never fetched a
namespace therefore reports every ref in it as removed. Local absence is not
removal: the archive is frozen upstream by ruleset, and a clone's failure to
fetch it is evidence about the clone.

Distinguish the two cases in `problems`:

1. Before the per-ref loop, count how many of the witness's refs under this
   `prefix` have a local counterpart in `actual`. The prefix is already a
   parameter (`local function problems(root: string, raw: string, prefix: string): {string}`).
2. When that count is zero and the witness holds at least one ref under the
   prefix, emit exactly one line instead of the per-ref lines:
   `archive: <prefix> not fetched (N refs in witness); fetch it: git fetch --atomic <remote> '+refs/heads/<prefix>/*:refs/remotes/<remote>/<prefix>/*'`
   — the same shape as the marker refusal, naming what to run rather than what
   is missing.
3. When the count is non-zero, keep today's behaviour exactly: a namespace that
   is partly present is a genuine divergence and every removed, moved and added
   ref is still named individually.

With all four namespaces unfetched the refusal becomes four lines instead of
1,991, and each one says what to do.

`_work/migrate6_archive.tl` is 144 lines (`wc -l`), well inside the 500-line
cap, and the change adds roughly fifteen.

Regression: `_work/migrate6_archive_test.tl` (new file) builds a witness over two
prefixes, snapshots a root where one prefix is wholly absent and the other has
one ref moved, and asserts the absent prefix yields exactly one `not fetched`
line carrying its ref count while the partly-present prefix still yields its
per-ref `moved` line.

The module has no `.cosmic-coverage` row today (`grep -n "migrate6_archive" .cosmic-coverage`
returns nothing against 91 rows, `grep -c '\["_' .cosmic-coverage`), so adding
the test may add one. Measure it with `bin/cosmic --make coverage`, add that row
alone, and carry the measured basis with it; never regenerate the whole floor.
