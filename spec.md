# cosmic.htmx: the HX-* contract as pure functions over http.Request/http.Response — fragment-or-page reply, request predicates, response headers, OOB

## Goal

Make htmx a one-liner at every point it touches the server, without
teaching the server anything: a module of pure functions that read
`req.headers` and call `res:set_header`, plus the one helper that
carries the whole idiom — reply with a fragment when htmx asked, the
full page otherwise. This is what Go's htmx helper libraries are
(request predicates, response-header setters, a partial-vs-full
render), typed.

## Evidence

Ready when: `ls cosmic/http/init.tl` prints `cosmic/http/init.tl`.

That is the core child merged; today the command reports the path as
missing.

The htmx wire contract this module covers, from the htmx reference
(https://htmx.org/reference/#request_headers and
`#response_headers`) — request: `HX-Request`, `HX-Boosted`,
`HX-Current-URL`, `HX-History-Restore-Request`, `HX-Prompt`,
`HX-Target`, `HX-Trigger`, `HX-Trigger-Name`; response: `HX-Location`,
`HX-Push-Url`, `HX-Redirect`, `HX-Refresh`, `HX-Replace-Url`,
`HX-Reswap`, `HX-Retarget`, `HX-Reselect`, `HX-Trigger`,
`HX-Trigger-After-Settle`, `HX-Trigger-After-Swap`. The puller
re-checks that page and names any header added since in the PR.

The typed pieces it composes: `cosmic.html.SafeHtml`
(`cosmic/html.tl:44`), `cosmic.json.encode` (`cosmic/json.tl:84`) for
`HX-Trigger`'s JSON form, `cosmic.url.SafeUrl` (`cosmic/url.tl:347`)
for the URL-carrying headers, and the core child's `Request.headers`
(lowercase names) and `Response:set_header`/`:html`.

## Change

New file `cosmic/htmx.tl` (H1: "htmx helpers: read the HX-* request
headers, set the HX-* response headers, and reply with a fragment or a
page. Pure functions over cosmic.http's Request and Response."):

- Request predicates and readers, each `function(req: http.Request)`:
  `is_request(): boolean` (`hx-request == "true"`), `is_boosted()`,
  `is_history_restore()`, `target(): string | nil`, `trigger(): string
  | nil`, `trigger_name(): string | nil`, `prompt(): string | nil`,
  `current_url(): string | nil`.
- Response setters, each `function(res: http.Response, ...)`:
  `redirect(res, url: url.SafeUrl)` (`HX-Redirect`), `location(res,
  url: url.SafeUrl, opts?: LocationOptions)` (`HX-Location`; with
  `opts` it is the JSON object form — `target`, `swap`, `select`,
  `values`), `push_url(res, url: url.SafeUrl | false)` (`false` emits
  `"false"`), `replace_url(res, ...)` likewise, `refresh(res)`,
  `retarget(res, selector: string)`, `reswap(res, spec: string)`,
  `reselect(res, selector: string)`, `trigger(res, events: string |
  {string: any}, when?: "settle" | "swap")` — a string is emitted
  verbatim (comma-joined names allowed), a table is `json.encode`d
  (event name → detail); `when` selects the `-After-Settle`/`-After-
  Swap` header. Every setter returns nothing: `set_header` is
  infallible on a record.
- The idiom: `reply(req: http.Request, res: http.Response, fragment:
  html.SafeHtml, page: function(html.SafeHtml): html.SafeHtml)` — sends
  `fragment` alone when `is_request(req)` and not `is_boosted(req)` and
  not `is_history_restore(req)`, else `page(fragment)`; both via
  `res:html`. The type of `page` is the point: a layout is a function
  from a fragment to a page, which is exactly what a compiled
  `cosmic.template` in `{{mode html}}` composes (its `render` returns
  `SafeHtml`), so no new template feature is needed.
- `oob(fragment: html.SafeHtml, id: string, opts?: OobOptions):
  html.SafeHtml` — wraps in `<div id="<id>" hx-swap-oob="true">…</div>`
  (`opts.swap` sets the attribute value, `opts.tag` the element; `id`
  through `html.escape_attr`, `cosmic/html.tl:74`). Concatenate the
  result after a primary fragment; htmx swaps it out of band.
- Tests `cosmic/htmx_test.tl`, pure: fake `Request` records with the
  headers set/unset; a `Response` double capturing headers and the
  `html` body; every predicate both ways; each setter's exact header
  name and value including the JSON forms (`HX-Trigger:
  {"saved":{"id":3}}`), `push_url(false)`; `reply` all four branches;
  `oob` output with escaping.
- `cosmic/htmx_example.tl`: `Example_reply` — two requests, one with
  `HX-Request: true`, through a `serve_one`, printing both bodies.

## Non-goals

- Nothing in `cosmic/http/` changes. If a needed `Response` method is
  missing, that is a child of this item, not a reach into the server.
- No htmx JS asset, no CSRF, no session: the guide child.
- No `hx-*` attribute builders for templates: attributes are text in a
  `.tmpl`; the template module's `attr` context already types them.

## Access

- cosmic-lua/cosmic: read+write.
