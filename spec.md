# cosmo.http silently collapses duplicate Content-Length headers instead of rejecting the disagreement

## Evidence

Found during adversarial review of «FyJ2_UFwQ» (`cosmic.http` core),
hunting for request-smuggling-adjacent framing bugs.

A request carrying two different `Content-Length` values is a smuggling
vector (RFC 9112 §6.3: a recipient MUST reject a message with multiple
differing `Content-Length` values, or with a `Content-Length` and a
`Transfer-Encoding` disagreeing) — different intermediaries that resolve
the ambiguity differently disagree about where one request ends and the
next begins.

Reproduced live against `cosmic.http`'s current build (item
«FyJ2_UFwQ», commit `115a04791909694af201fddded4a8d7b57f5fda2`):

```
POST /a HTTP/1.1
Host: h
Content-Length: 5
Content-Length: 6

AAAAAA...
```

The handler sees `cl=6` and a 6-byte body — no rejection, silent
last-wins.

Root cause is one layer down, in `cosmo.http` itself
(cosmic-lua/cosmopolitan): `o/_types/types_gen/cosmo/http.d.tl`
documents the binding's own header-merge behavior — a non-repeatable
header name (`Content-Length` is not in the repeatable set) "holds a
string, a later occurrence replacing an earlier one." So by the time
`cosmic.http`'s Lua layer sees `raw_headers["content-length"]`, the
duplicate is already gone — there is exactly one value, and no local
re-scan of the already-consumed head can recover which of several
duplicates was silently dropped without re-parsing the raw bytes
`cosmo.http` already consumed.

`cosmic/http/init.tl:196-197` does still hold the raw head bytes in
`buf` before slicing them off, so a workaround INSIDE `cosmic.http`
(re-scanning the raw head text for repeated `Content-Length:` lines) is
technically possible, but re-implementing header-line scanning in Lua
duplicates what the C parser already did and is exactly the kind of
duplicated-parsing surface that invites its own divergence bugs — the
right fix is almost certainly in the binding itself, since it already
does the one authoritative parse of the wire bytes.

## Direction (not a ready fix — triage this)

Two shapes, either landing in cosmic-lua/cosmopolitan's `tool/net/lhttp.c`:

1. Have the binding refuse (return `nil, "duplicate Content-Length"` or
   similar from `parse`) when it sees the same non-repeatable header
   name more than once with different values — matching RFC 9112's own
   MUST. This changes the binding's documented merge behavior for
   `Content-Length` specifically (and arguably any non-repeatable
   header where RFC 9110/9112 requires rejecting a disagreement,
   though `Content-Length` is the one with real smuggling stakes).
2. Alternatively, expose enough from the binding (a raw duplicate-count
   or a list of all values seen per header, at least for
   `Content-Length`) for `cosmic.http` to make its own rejection
   decision without re-parsing raw bytes.

Either is a binding contract change and needs the matching
`definitions.lua` update in the same commit per cosmic-lua/cosmopolitan's
AGENTS.md ("binding contracts... are frozen at the C boundary...
a deliberate contract change needs a matching definitions.lua update").
`cosmic.http`'s own `body()`/`Content-Length` handling
(`cosmic/http/init.tl:214-221`, item «FyJ2_UFwQ») would then read the
binding's new signal instead of continuing to trust a merged value.

## Non-goals

- Not a `cosmic.http` (Lua layer) bug in isolation — the merge already
  happens before that layer sees the headers. A local Lua workaround
  that re-scans raw head bytes is explicitly discouraged above in favor
  of fixing the one authoritative parse.
- Not scoped to fix every non-repeatable header's duplicate handling —
  start with `Content-Length` (the one with a documented RFC MUST and
  real smuggling consequence); a broader audit is separate.

## Access

- cosmic-lua/cosmopolitan: read+write (where the binding fix lands).
- cosmic-lua/cosmic: read+write (where `cosmic.http` reads the binding's
  new signal, once the binding changes).
