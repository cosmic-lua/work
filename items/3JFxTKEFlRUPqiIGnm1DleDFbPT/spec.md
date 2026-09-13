# cosmic.http refuses a body over ~32KB with 400 whenever the client delivers it faster than one recv can drain — inherited core defect, not this item's

## Evidence

Found during adversarial review of «gWQu_76VE» (cosmic.http streaming);
the mechanism predates that item (traced to `10fe9042`, the
cosmic.http core, «FyJ2_UFwQ») and affects `Content-Length` bodies
identically, not just chunked ones — filed separately since neither
item's own scope covers it.

`cosmic/http/init.tl:185` hands the ENTIRE accumulated receive buffer
(head + however much of the body has arrived so far) to
`parser:parse(buf)` on every loop iteration, before either the
`Content-Length` or chunked body-reading path runs. `ParseHttpMessage`
(the C binding underneath) truncates its accepted length to
`SHRT_MAX` (`net/http/parsehttpmessage.c:112-113`) and returns nil —
which `cosmic.http`'s loop treats as a parse failure, refusing 400 —
once head+however-much-of-body-is-buffered exceeds 32767 bytes.

Bisected exactly on the streaming item's build: a 57-byte head plus
32710 raw body bytes arriving before the next `parse` call → 200; add
one more byte (32711) → 400. Reproduced identically by sending a
`Content-Length`-framed body (not just chunked) fast enough that a
`recv` pulls a body chunk large enough to cross the threshold together
with whatever's already buffered.

The practical effect: `ListenOptions.max_body_bytes` defaults to
1048576 (1 MiB) and is documented as the real limit
(`cosmic/http/init.tl:55-60`), but a client that writes its request in
large, fast chunks (a normal HTTP client on a fast connection, not
anything adversarial) never reaches that path — it gets refused 400 at
~32 KiB purely because of how much of the body happened to already be
buffered next to the head when `parse` was last called. A client that
trickles bytes slowly enough for `body()`/`read_chunked` to drain the
buffer between `recv`s never hits it. So today's actual behavior is:
"large bodies work only from slow/trickling clients" — the opposite of
what a server usually wants, and silently so.

## Direction (not a ready fix — triage this)

The core issue is calling `parser:parse(buf)` with the FULL buffer
(head prefix + all buffered body bytes) on every iteration, when only
the HEAD portion needs (re-)parsing once a body-reading path has taken
over. Once the head is known to be complete (a prior `parse` call
already returned a positive length), the loop should stop re-parsing
growing buffer for body bytes at all — the head length is already
known, and body bytes past it belong to `body()`/`read_chunked`
verbatim.

Two shapes to weigh:
1. Only call `parse` on bytes that have NOT yet been identified as
   past a completed head — i.e., re-parse only while accumulating the
   head, and once `parse` returns a positive head length, never call
   it again on that connection's buffer until `reset` for the next
   message. This may already be closer to intended usage of
   `cosmo.http.parser`'s per-message contract; worth checking whether
   the connection loop already keeps enough state to know "head is
   done" and simply isn't using it to skip the re-parse.
2. If re-parsing genuinely needs the full buffer for some reason not
   evident from this write-up, split what's handed to `parse` from
   what's buffered for the body reader, so the SHRT_MAX ceiling applies
   only to the head as `max_head_bytes` already documents, not to
   head+body combined.

Whichever shape, a regression belongs in `cosmic/http/init_test.tl` or
`stream_test.tl`: a body well under `max_body_bytes` (e.g. 100 KiB),
sent in one or two large writes (not drip-fed), must succeed — today
it doesn't.

## Non-goals

- Not specific to chunked encoding — reproduces identically with
  `Content-Length`, so the fix belongs wherever the connection loop's
  `parse` call lives (`cosmic/http/init.tl`), not in either the
  core's or streaming's request-body-specific code.

## Access

- cosmic-lua/cosmic: read+write.
