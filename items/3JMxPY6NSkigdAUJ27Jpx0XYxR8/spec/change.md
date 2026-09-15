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

`problems`'s `prefix` parameter is NOT a legacy namespace: it is the private
namespace the migration fetched INTO, computed by the caller as `refs/heads/`
in local mode or `refs/remotes/<remote>/` otherwise
(`grep -n 'local prefix = refs.board_mode(root) == "local" and "refs/heads/"' _work/stateread_fsck.tl`),
and `canonical` maps a ref under it back to a `refs/heads/...` name
(`grep -n "local function canonical(ref: string, prefix: string)" _work/migrate6_archive.tl`).
So the grouping is by the LEGACY namespace read off the canonical name, which
`legacy_name` already enumerates
(`grep -n "local function legacy_name(ref: string): boolean" _work/migrate6_archive.tl`):
`refs/heads/items/`, `refs/heads/ended/`, `refs/heads/claim-batches/`, and the
single ref `refs/heads/board/seq`.

Distinguish the two cases in `problems`:

1. Add `namespace_of(name: string): string | nil` returning the grouping key for
   a canonical name: the first three patterns yield their namespace without the
   trailing slash, and `refs/heads/board/seq` yields nil — see 4.
2. Before the per-ref loop, bucket the witness's refs by `namespace_of` and count,
   per bucket, how many have a local counterpart in `actual`.
3. When a bucket's present-count is zero and it holds at least two witness refs,
   emit exactly one line in place of that bucket's per-ref lines:
   `archive: <namespace> not fetched — N of N witness refs absent locally; fetch it: git fetch --atomic <remote> '+<namespace>/*:<prefix><segment>/*'`
   where `<remote>` is `refs.board_remote(root)` (add the `_work.refs` require),
   `<prefix>` is the parameter, and `<segment>` is the namespace's last path
   component. In local mode `prefix` is `refs/heads/`, so the remedy names a
   fetch into the canonical names themselves; emit the same line, since a wholly
   absent bucket is the same fact either way.
4. `refs/heads/board/seq` is one ref, so "absent because never fetched" and
   "absent because deleted" are indistinguishable for it. It keeps today's
   per-ref `archive: removed` line — which is why the two-ref floor in 3 exists
   rather than a bare zero-present test.
5. When a bucket's present-count is non-zero, keep today's behaviour exactly: a
   partly-present namespace is a genuine divergence and every removed, moved and
   added ref is still named individually. `moved` and `added` are never
   collapsed, in any bucket.

With the three multi-ref namespaces unfetched the refusal becomes three lines
plus `board/seq`'s one, instead of 1,991.

`_work/migrate6_archive.tl` is 144 lines (`wc -l`), well inside the 500-line
cap, and the change adds roughly thirty-five. Measure that against a formatted
tree, not before the fmt stage runs.

Regression: `_work/migrate6_archive_test.tl` (new file) builds a witness over two
prefixes, snapshots a root where one prefix is wholly absent and the other has
one ref moved, and asserts the absent prefix yields exactly one `not fetched`
line carrying its ref count while the partly-present prefix still yields its
per-ref `moved` line.

The module has no `.cosmic-coverage` row today (`grep -n "migrate6_archive" .cosmic-coverage`
returns nothing against 91 rows, `grep -c '\["_' .cosmic-coverage`), so adding
the test may add one. Measure it with `bin/cosmic --make coverage`, add that row
alone, and carry the measured basis with it; never regenerate the whole floor.
