## Evidence

Every read verb pays for git processes it does not need. Measured 2026-09-04
on release 2026-09-04-98dd25d against the live board (915 items), warm cache,
`strace -f -e trace=execve -s 200` on `o/bootstrap/gitboard <verb>` with
`GITBOARD_DIR=o/board`:

`show` (0.18 s, 6 git processes) runs, in order: `for-each-ref` over
items/ended/board, `cat-file --batch` ×3 (the load's three passes), then
`for-each-ref` over the same three namespaces AGAIN and a fourth `cat-file
--batch`. The second snapshot is the cache's digest check
(`_work/cache.tl`), taken after `_work/gitread.load` already took one; and
the whole board is loaded from git although the cache is current.

`show ID` (0.17 s, 12 git processes) runs: `for-each-ref` on the id prefix
glob, `for-each-ref` on the resolved full ref, `cat-file --batch`, then the
same 5-process whole-board load as `show`, then `cat-file -p
<ref>:spec.md` TWICE, `log --format=... <ref>`, `remote get-url origin`, and
one more `cat-file --batch`. The spec body is read twice by two callers
after the load already had it in a batch; the id resolution takes two
snapshots where one suffices.

Startup of the binary itself is 7 ms (`--help`); each git process costs
roughly 25 ms here, so these verbs are 90% process spawn.

## Change

One ref snapshot per run, one load, nothing read twice — the read verbs'
process count drops and `show`/`next` approach `find`'s 0.02 s. This is
NOT the SQL-views item («BZCt_Z5l7» decides how verbs read the cache); it
removes duplicate git work on the path that exists today, and lands
independently of it.

1. `_work/store.tl` / `_work/cache.tl`: the digest the cache validates
   against is computed from the ref snapshot the load already took — pass
   the `for_each_ref` result (or its digest) into the cache check instead
   of re-running `for-each-ref`. One snapshot per process.
2. `_work/gitread.tl` id resolution (`show ID`, and every verb taking an
   id): resolve a prefix or handle from the snapshot already in hand (the
   ref list is in memory) — zero extra processes — falling back to a
   single `for-each-ref` glob only when no snapshot exists yet.
3. `_work/gitshow.tl` (and whichever second caller reads `spec.md`): the
   spec body comes from the loaded Item (`read_specs` batched it) — delete
   the two `cat-file -p <ref>:spec.md` calls. `remote get-url origin` is
   read once per process and memoized in the store, not per render.
4. `git log` for the item's history stays: it is the one thing the load
   does not carry. Name it in the code as the one deliberate process.
5. Tests: `_work/procs_test.tl`'s table (the process ratchet; ready when it
   is on main — `bin/cosmic --make test _work/procs_test.tl` passes)
   records the new counts: `show` and `next` at 4 (one `for-each-ref`,
   three `cat-file --batch`), `show ID` at 5 (those plus `log`). If the
   load's three `cat-file --batch` passes can become one process with
   `--batch` reads interleaved, do it in this PR only if it stays under
   the file caps; otherwise leave that as a note in the PR.

## Non-goals

Reading Items from the cache instead of git (that is «BZCt_Z5l7»);
changing any output; changing mutation verbs (their write path is the
in-Lua hashing change and the fast-import stream, separate work).
