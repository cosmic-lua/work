1. `_work/gitbatch_test.tl`: one case whose round's request bytes AND
   answer bytes both exceed a pipe buffer (64 KiB on Linux): enough
   distinct blobs of a few KiB each, queried in one `BatchSession` round.
   It asserts every answer matches its blob.
2. The case must FAIL under the mutation `CHUNK_QUERIES = 1000000` and
   must not hang the suite when it fails: bound the wait (a deadline on the
   read, or a size guard that refuses an unchunked round before writing)
   so the failure is a message, not a stuck process.
3. Nothing else changes; `_work/gitbatch.tl` is touched only if the
   bounded-wait guard needs a hook there.
