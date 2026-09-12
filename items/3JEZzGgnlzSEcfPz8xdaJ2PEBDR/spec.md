# cosmic.http forms and cookies: `req:form()` for urlencoded bodies, `req.cookies`, and `res:set_cookie` with the secure defaults

## Goal

htmx submits forms: `hx-post` on a `<form>` sends
`application/x-www-form-urlencoded` (its default `hx-encoding`), and a
session is a cookie. Give `Request` a typed, decoded form and cookie
jar, and `Response` a `Set-Cookie` writer whose defaults are the safe
ones, so an app never string-builds either header.

## Evidence

Decoding exists: `cosmic/url.tl:63` `local function parse_query(query:
string): {string: {string}}` over `cosmo.ParseParams` (`:64`), which is
exactly the urlencoded-body grammar. Nothing parses a `Cookie` header
or writes `Set-Cookie` anywhere in `cosmic/`:

```
$ grep -rn -i 'set-cookie\|cookie' cosmic/*.tl cosmic/*/*.tl | grep -v _test
cosmic/fetch/init.tl:70:  --- arrival order. Use for repeatable headers like Set-Cookie.
```

— one doc-comment mention on the client side, no parser or writer.
(Re-run at pull; a second hit means a sibling landed one — reuse it.)

## Change

Ready when: `ls cosmic/http/init.tl` prints `cosmic/http/init.tl`.

That is the core child merged; today the command reports the path as
missing.

- `cosmic/http/request.tl`:
  - `form(self): {string: {string}} | nil, string` — when
    `Content-Type` is `application/x-www-form-urlencoded` (parameters
    after `;` ignored), `url.parse_query(self:body())`; any other type
    → `nil, "not a form: <content-type>"`; memoized. `multipart/
    form-data` is refused with the same shape and named in the
    message — it is its own item (file uploads).
  - `cookies: {string: string}` — parsed once from `Cookie` (RFC 6265
    §5.4: `;`-separated `name=value` pairs, OWS trimmed, first
    occurrence wins, malformed pairs skipped), `{}` when absent.
- `cosmic/http/response.tl`: `set_cookie(self, name: string, value:
  string, opts?: CookieOptions): boolean, string` — `record
  CookieOptions` with `path` (default `/`), `max_age_s: integer`,
  `expires: integer` (unix seconds → `FormatHttpDateTime`), `domain`,
  `secure: boolean` (default true), `http_only: boolean` (default true),
  `same_site: string` (`"Lax"` default; `"Strict"`/`"None"`; `"None"`
  with `secure = false` is refused). `name` must be an HTTP token and
  `value` a cookie-value (RFC 6265 cookie-octet set, checked with one
  Lua pattern in the module — quote the pattern in the doc comment);
  a bad one returns `false, msg`. Emits one `Set-Cookie` header per
  call via `add_header`. `clear_cookie(self, name, opts?)` is
  `set_cookie` with `max_age_s = 0` and an empty value.
- Tests `cosmic/http/form_test.tl`, pure: urlencoded body → table
  (repeated keys, `+` and `%20`, empty values); wrong content type
  error; cookie header parsing table; `set_cookie` header string for
  defaults (`name=value; Path=/; Secure; HttpOnly; SameSite=Lax`), each
  option, `SameSite=None` without Secure refused, bad name/value
  refused; `clear_cookie`.
- `cosmic/http/init_example.tl`: `Example_form` — POST a form through
  `serve_one`, echo one field.

## Non-goals

- `multipart/form-data`: its own item, named here so a puller does not
  fold it in.
- Signed/encrypted session cookies (needs the `cosmic.crypto` decision,
  «Y45A_uF50»): out of scope; the guide shows a server-side session
  table keyed by a `cosmic.rand` token instead.
- CSRF tokens: an app-level pattern the guide shows; no server support
  in this slice.

## Access

- cosmic-lua/cosmic: read+write.
