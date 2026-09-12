## Change

Make exact response completion the only route back to buffered Fetch's HTTP
pool. Step 2 of `uQsI_Q5CM`; cosmic-lua/cosmopolitan master. Its child (step 1)
must land first; preserve its route/policy checks and the legacy table adapter.

Source snapshot e748d6a1e: `rg -n -F 'Finished:' tool/net/fetch.inc` prints
836; `rg -n -F 'FetchHeaderEqualCase(kHttpConnection, "close")'` prints 846;
`rg -n -F 'return u->i;' net/http/unchunk.c` prints 118. This is source evidence;
the new edge-case outcomes below are specifications, not executed results.

Add internal `tool/net/fetchframing.inc` with a small per-response eligibility
record and bounded header-field/token scan. Retain the existing parser and its
body results. Record whether framing is exact Content-Length, complete chunked
or bodyless 204/304, how many encoded bytes were consumed, whether EOF supplied
the delimiter, version, close/upgrade tokens and framing ambiguity. Parse all
Connection values including xheaders, comma-separated and case-insensitive.
Duplicate framing fields or TE+CL make reuse ineligible even when the existing
parser returns a response; do not broaden its accepted grammar or redefine
existing success/error shapes. Malformed/truncated responses already rejected
must still return nil/message/kind and close.

Allow pooling only for HTTP/1.1, final response, exact self-delimited end, no
surplus read-ahead and no close token in either direction. Track Unchunk's wire
return separately from its decoded paylen. EOF-delimited bodies always close.
Mark HEAD, CONNECT, 101/Upgrade and HTTP/1.0 ineligible. HEAD's existing parsing
bug belongs to `G4GV_lics`; do not duplicate or claim to fix it here.
After interim 1xx, parse bytes already in the buffer before reading again.
Keep existing maxresponse and timeout meanings.

Delay returning transport to the pool until this response's redirect checks
finish. Success, refusal, redirect recursion and errors each transfer or close
it exactly once. The HTTPS downgrade refusal must not close an already inserted
socket. Retain existing method/body transformations, credential stripping,
options immutability, and final URL. No automatic replay is added.

Add `tool/lua/test_fetch_pool_framing.lua` with raw loopback responses:
1. CL=0/nonzero, 204/304, complete chunked body+trailers: repeat request on same
   connection; assert every body and per-socket ordinal.
2. Fragment chunks/trailers across writes; coalesce 100+200 in one write and
   assert completion without waiting for more bytes. Server barriers, not sleep.
3. `Connection: keep-alive, CLOSE`, multiple Connection fields, HTTP/1.0,
   EOF-delimited body: next request uses a fresh socket.
4. CL/chunk truncation: existing failure, no reuse. CL/chunk surplus and duplicate
   CL or TE+CL: force close; next response cannot consume surplus bytes. Pin the
   old first-call result only after measuring it; the reuse assertion is fixed.
5. Same-origin redirect reuses only after full consumption; cross-origin changes
   socket and retains existing credential behavior. Refusal never leaves stale fd.

Run binding gate and redbean build as in step 1. Mutation-check close-token and
encoded-versus-decoded consumption guards. Keep protocol assertions as permanent
tests. No changes to net/http's shared parser or C success/failure arities.

## Access

Read cosmic-lua/cosmic for wrappers, benchmarks, pins and skills; read
cosmic-lua/cosmopolitan for transport sources, native tests and release evidence;
read cosmic-lua/work for the parent design and prerequisite evidence, supplied
by the orchestrator in the builder brief. The implementation PR targets only
the repository assigned to this item; agents do not mutate the board.
