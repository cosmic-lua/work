## Evidence

cosmic-lua/work#29 («baNR_tA4O») landed `_work/gitbatch.tl`'s BatchSession
with 64-query chunked pipelining, whose purpose is to keep a round from
deadlocking when both the request bytes and the answer bytes exceed a pipe
buffer. Its review (2026-09-05) found no test that fails when the chunking
is removed: setting `CHUNK_QUERIES = 1000000` in `_work/gitbatch.tl`
passes the whole suite. The PR merged through the merge queue on the
recorded accept before the builder's follow-up commit (84febbeb on branch
`3IszjUoY`, "gitbatch_test: cover the pipe-saturating round chunking
actually guards") could land.

## Change

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

## Non-goals

Changing the chunk size; changing BatchSession's API; any other module.
