Ready when: `ls cosmic/http/init.tl` prints `cosmic/http/init.tl`.

That is the core child merged; today the command reports the path as
missing.

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
