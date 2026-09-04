## Evidence

Mutation verbs re-read the whole board several times in one run. Measured
2026-09-04 on release 2026-09-04-98dd25d in a sandbox clone of the live board
(917 items) with a LOCAL bare origin, `strace -f -e trace=execve -s 300 -o
st.txt o/bootstrap/gitboard <verb> ...` then `grep -o 'execve("[^"]*git",
\[[^]]*\]' st.txt` (git's own children under `/usr/lib/git-core/` are the
push's pack/unpack and the local origin's receive side, not gitboard's):

`new TITLE --parent P --spec-file F` — 21 git processes, 0.25 s, of which
gitboard itself spawns 14: `for-each-ref` on the parent's prefix glob;
`for-each-ref` over items/ended/board + `cat-file --batch` ×3 (the load);
`remote get-url origin`; `for-each-ref` over all three namespaces TWICE
more; `cat-file -p refs/heads/items/<new-id>:spec.md` and `cat-file -p
refs/heads/ended/<new-id>:spec.md` (a spec read for an id that does not exist
yet, tried under both namespaces); `fast-import --quiet --done`;
`for-each-ref` on the new ref; `for-each-ref` over all three namespaces a
FOURTH time; `remote`; `push --atomic --force-with-lease`.

`compare A B` — 22 git processes, 0.36 s, of which gitboard spawns 16:
`for-each-ref` over all three namespaces ×4, `cat-file --batch` ×6, three
single-id `for-each-ref` lookups, `fast-import`, `remote`, `push`. Six
`cat-file --batch` means the board's content was loaded twice.

The write itself is already one process (`fast-import` with inline blobs; no
`hash-object`/`mktree` anywhere on this path) plus the push. Everything
else is the same snapshot and the same load, repeated: a `new` spends about
0.15 s of its 0.25 s on reads it has already done.

## Change

A mutation verb takes ONE ref snapshot and ONE load before it writes, and
re-reads only the refs it wrote. Ready when: `_work/procs_test.tl` (the
process ratchet) is on main — `bin/cosmic --make test _work/procs_test.tl`
passes — so the new counts are recorded, not asserted by hand.

1. Find every `refs.for_each_ref` and `gitread.load` call reachable from
   `new`/`compare`/`block`/`take`/`done` (start at `_work/gitverbs.tl`,
   `_work/gitwrite.tl`, `_work/publish.tl`, `_work/store.tl`,
   `_work/cache.tl`; `grep -n "for_each_ref\|gitread.load\|load_many"
   _work/*.tl | grep -v _test` is the sweep — paste its count into the
   PR). The store already holds the snapshot and the loaded Items; the
   lease check before the write, the cache's digest check, and the post-save
   tip read-back must all consume what the store holds. After the write,
   read back ONLY the refs the fast-import touched (one `for-each-ref` with
   those refnames, which `new` already does) and patch the cache from the
   Items in memory, which `_work/cache.tl` already supports (cosmic-lua/work#14).
2. `new`: do not read `spec.md` for the id being minted. Locate the
   `read_spec`/spec-sidecar call that runs before the item exists and skip
   it when the id is not in the snapshot; the `--spec-file` body IS the spec.
3. `remote get-url origin` and `remote` (the push's remote listing) are read
   once per process and memoized on the store; they are the same two facts
   `show ID` reads.
4. Target counts, recorded in the ratchet table when they hold: `new` at 6
   gitboard-spawned git processes (one glob lookup, one snapshot, three
   `cat-file --batch`, `fast-import`, the ref read-back, `push` — fewer if
   the load's three batches merge), `compare` at 7. Output unchanged: the
   `gitboard-new:`/`gitboard-compare:` lines and every refusal string are
   frozen; `_work/gitcompare_test.tl` and the verb tests must pass unedited.

## Non-goals

Changing the fast-import stream or the lease/CAS protocol
(`push --atomic --force-with-lease` stays the write); the read verbs'
duplicate snapshot (its own item); reading Items from the cache instead
of git («BZCt_Z5l7»).
