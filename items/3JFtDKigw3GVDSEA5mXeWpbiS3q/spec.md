# cosmic.http silently ignores an unrecognized Transfer-Encoding value instead of refusing it

## Evidence

Found while building «gWQu_76VE» (cosmic.http streaming); out of that
item's scope since its own `## Change` only names the `chunked` case.

`cosmic/http/init.tl:227-252`'s framing dispatch:

```
local encoding = (req:header("transfer-encoding") or ""):lower()
local declared = req:header("content-length")
if encoding:find("chunked", 1, true) then
  ...
elseif declared ~= nil then
  -- Content-Length path
  ...
end
```

A `Transfer-Encoding` header whose value does not contain `"chunked"`
(e.g. `Transfer-Encoding: gzip`, `Transfer-Encoding: identity`, or any
future/unknown coding this server cannot decode) falls straight into
the `elseif declared ~= nil` branch and the server frames the request
by `Content-Length` instead — silently ignoring a transfer coding it
does not understand.

RFC 9112 §6.1: "A server that receives a request message with a
transfer coding it does not understand SHOULD respond with 501 (Not
Implemented)." A server that instead falls back to `Content-Length`
while a downstream proxy honors the `Transfer-Encoding` header
disagrees with that proxy about the request's framing — the same
smuggling-shape family as the `Transfer-Encoding: chunked` +
`Content-Length` double-framing case this item already refuses with
400 (`init.tl:230-235`).

## Direction (not a ready fix — triage this)

Extend the dispatch: an `encoding` that is non-empty but does not
contain `"chunked"` should refuse with 501 (matching the RFC's SHOULD),
rather than falling through to the `elseif declared ~= nil` branch.
This is a small, local addition to the same `if`/`elseif` chain
«gWQu_76VE» just extended for the TE+CL double-framing case — likely a
new branch ahead of the existing `elseif`, refusing before either the
chunked or content-length paths are reached.

Worth a regression case alongside the existing
`test_chunked_body_beside_content_length_is_refused` (from
«gWQu_76VE») pinning that `Transfer-Encoding: gzip` (no
`Content-Length`) refuses with 501, and that `Transfer-Encoding: gzip`
alongside a `Content-Length` also refuses (whichever status is judged
correct — 501 for the unknown coding, or the existing 400 for the
double-framing, whichever this repo's convention prefers when both
apply).

## Non-goals

- Not a request to implement `gzip`/other transfer codings — only to
  refuse them cleanly instead of silently ignoring them.

## Access

- cosmic-lua/cosmic: read+write.
