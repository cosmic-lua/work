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
