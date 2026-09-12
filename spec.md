# cosmic.http.router: method + path-pattern dispatch with `:param` segments, as a Handler

## Goal

The one piece every htmx app has on page one: `GET /todos` renders the
list, `POST /todos` adds one, `DELETE /todos/:id` removes one and
returns the fragment. A router is a `Handler` (so it plugs into
`Server:serve` unchanged) that dispatches on method and path pattern
and fills `req.params`.

## Evidence

The core child defines `type Handler = function(req: Request, res:
Response)` and `Request.path` (percent-decoded via `cosmic.url.parse`,
`cosmic/url.tl:125`) — the router matches on that. `Request` gets a
`params: {string: string}` field here, empty for a request that never
went through a router.

## Change

Ready when: `ls cosmic/http/init.tl` prints `cosmic/http/init.tl`.

That is the core child merged; today the command reports the path as
missing.

New file `cosmic/http/router.tl` (module `cosmic.http.router`):

- `new(): Router`.
- `Router:get(pattern: string, h: Handler)`, `:post`, `:put`, `:patch`,
  `:delete`, `:head`, `:options`, and `:any(pattern, h)`.
- Pattern grammar, stated in the module doc: literal segments; a
  `:name` segment matches one non-empty segment (no `/`) into
  `req.params[name]`; a trailing `*name` matches the rest of the path
  (may be empty). A pattern is validated at registration — an empty
  segment, a `:` with no name, a `*` not in last position — and
  `new`'s methods return `boolean, string` (`false, msg` on a bad
  pattern) rather than throwing (library code never throws).
- `Router:handler(): Handler` — the function to hand `Server:serve`.
  Matching is first-registered-wins in source order; a path that
  matches a pattern under a different method answers 405 with an
  `Allow` header listing the methods registered for it; nothing
  matched answers 404. `HEAD` falls back to a `GET` route with the body
  dropped (`Content-Length` kept).
- `Router:not_found(h: Handler)` overrides the 404 body (a page, or an
  htmx fragment).
- `cosmic/http/request.tl`: add `params: {string: string}`.
- Tests `cosmic/http/router_test.tl` — pure, no sockets: build fake
  `Request`/`Response` records (the records are plain tables; a
  `Response` test double records status/headers/body) and assert:
  literal match, `:id` capture, `*rest` capture including empty, 404,
  405 with `Allow: GET, POST`, HEAD→GET, first-wins ordering, each bad
  pattern's error string.
- `cosmic/http/init_example.tl`: `Example_router` — three routes, two
  requests through `serve_one`.

## Non-goals

- Regex patterns, typed params, route groups/middleware — the least
  thing is `:param` and `*rest`. Middleware is function composition
  over `Handler` and needs no router support.
- Query-string routing.

## Access

- cosmic-lua/cosmic: read+write.
