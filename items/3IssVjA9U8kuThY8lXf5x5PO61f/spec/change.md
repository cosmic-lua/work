A mutation verb takes ONE ref snapshot and ONE load before it writes, and
re-reads only the refs it wrote. Ready when: «cwi5_ntHB» (the read verbs'
single snapshot, same store/cache seam) is merged — `git log --oneline
origin/main | grep -c "(#18)"` prints 1 (squash merges carry the PR
number, not the branch) — and the store split «Bkbr_5S1U» (PR #21, `grep -c
"(#21)"` prints 1) is on main, so the write half lives in
`_work/storewrite.tl` and this lands on top of both.

1. Find every `refs.for_each_ref` and `gitread.load` call reachable from
   `new`/`compare`/`block`/`take`/`done` (start at `_work/gitverbs.tl`,
   `_work/gitwrite.tl`, `_work/publish.tl`, `_work/store.tl`,
   `_work/storewrite.tl`, `_work/cache.tl`; `grep -n "for_each_ref\|gitread.load\|load_many"
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
4. Tests, in the diff: for `new` and `compare` on a fixture with a local
   bare origin, a case that counts calls to `refs.for_each_ref` and
   `gitread.load` (swap each on its module table for a counting stub, restore
   after) and asserts one snapshot and one load before the write plus one
   read-back of the written refs after; and a case that `new` never asks for
   `<new-id>:spec.md` (stub `gitobj`'s `cat-file -p` path to fail, `new`
   still succeeds). Expected after the change, for the builder's own check
   with the strace command above (not recorded in the tree): `new` at 6
   gitboard-spawned git processes (one glob lookup, one snapshot, three
   `cat-file --batch`, `fast-import`, the ref read-back, `push`), `compare`
   at 7. Output unchanged: the `gitboard-new:`/`gitboard-compare:` lines and
   every refusal string are frozen; `_work/gitcompare_test.tl` and the verb
   tests must pass unedited.
