One `cat-file --batch` process per load.

1. `_work/gitobj.tl`: a `batch_session(root)` that starts one `git cat-file
   --batch` through `cosmic.child`'s streaming API and exposes
   `request(shas) -> {sha: BatchEntry}` callable repeatedly, plus `close()`.
   The existing `cat_file_batch` becomes `batch_session` + one request +
   close, so every current caller is unchanged.
2. `_work/gitread.tl` `list` — the WHOLE-BOARD load whose three passes the
   Evidence measured, the path every `show`/`next` runs — and likewise
   `load` and `_work/gitreadmany.tl` `load_many`: open one session, issue
   the three rounds through it, close it. Parsing is untouched. A round is
   written in chunks while its answers are drained (never the whole round
   before reading anything, which deadlocks both pipes on a real board;
   never one query per answer either, which serializes ~2,800 round trips
   on the live board): write up to a bounded number of queries, read their
   answers, continue. Where `gitread.tl` or `gitobj.tl` have no room
   (both at 500 lines), the session lives in a new `_work/gitbatch.tl`.
2b. Wall time is the acceptance, not the process count: `show` on the live
   board, best of five, must not be slower than before this change; the
   builder measures both and records the numbers in the PR. A session that
   is slower than three processes is a finding to report, not to ship.
3. Tests: `_work/gitobj_test.tl` covers a session answering two rounds
   where the second round's shas come from the first round's answers, a
   missing sha in a round (`<sha> missing` line) not breaking later rounds,
   and close-after-error; `_work/gitread_test.tl` (from #18) asserts a
   `list` (and `load`) cost exactly one `cat-file` spawn each (count via the
   module-table stub pattern #18 introduced). Expected, for the builder's
   own strace check: bare `show` at 3 git processes for the load itself
   (`for-each-ref`, one `cat-file --batch`, `read_specs`' own batch) plus
   whatever the board's claimed items add (one `for-each-ref` each, a
   separate item).
