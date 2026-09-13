The `{{url ...}}` context in `cosmic.template`'s html mode splices a
`SafeUrl.raw` into an attribute unchanged (`cosmic/template/codegen.tl:141-143`),
and every per-component constructor except `safe_param` keeps `:`, `/`, `'`, `&`,
`(`, `)` (see Evidence). The PR's own idiom, `<a href="{{url .title |
cosmic.url.safe_path}}">` (`cosmic/template/init_test.tl:84`), therefore emits
`javascript:alert(1)` verbatim. Two changes in one PR — they are halves of one
contract, the html-mode `{{url}}` slot:

1. `cosmic/url.tl` (440 lines; the new function plus doc must fit under the
   500 cap — trim the `SafeUrl` doc block at 339-345 if needed): add
   `safe_href(str: string): SafeUrl`, infallible, the constructor for a WHOLE
   URL landing in an `href`/`src`/`action` attribute. Body: (a) if `str`
   contains any byte < 0x20 or 0x7f, return `{raw = "about:invalid"}` — browsers
   strip tab/newline before scheme detection, so `java\tscript:x` (which
   `url.parse` reads as scheme-less, see Evidence) would otherwise pass; (b)
   `local u = parse(str)`; nil → `about:invalid`; (c) accept when `u.scheme` is
   `http`, `https` or `mailto` (compare lowercased), or when `u.scheme == nil`
   AND `u.host == nil` (path-relative and absolute-path references); anything
   else — `javascript:`, `data:`, `vbscript:`, and the protocol-relative
   `//evil.com/x`, which parses to scheme nil / host `evil.com` — returns
   `about:invalid`; (d) accepted input returns `{raw = format(u)}`, so each
   component is re-escaped by the existing `format` (spaces to `%20`, extra
   leading slashes to `%2F`). `about:invalid` is WHATWG's always-failing URL;
   `trusted()` stays the hatch for a deliberate `//cdn` or custom scheme. Add
   `safe_href` to `UrlModule` and `M`. Rewrite the `SafeUrl` doc (339-345) and
   each `safe_param/safe_path/safe_segment/safe_host/safe_fragment` doc to say:
   these escape ONE COMPONENT of a URL whose scheme and authority the template
   text already fixes (`href="/users/{{url .id | cosmic.url.safe_segment}}"`);
   a whole URL from data goes through `safe_href`.
2. `cosmic/template/codegen.tl`: for `node.ctx == "url"` only, emit
   `parts[#parts + 1] = <html_alias>.escape(vN.raw)` instead of `vN.raw`
   (`ctx.html_alias` is already on `Ctx`, line 93). `html.escape` turns the
   `'`, `"`, `<`, `>`, `&` the path/fragment/authority tables keep into
   entities, which is what makes the value safe inside a quoted attribute; the
   tables already percent-encode space and backtick, so an unquoted attribute
   is covered too. Update the module doc at lines 7-15 to say the url context
   is the one context that escapes twice (URL rules in the constructor,
   attribute rules at the splice) and why. Update `cosmic/template/init.tl`
   17-29 to name `safe_href` as the whole-URL escaper.

Tests the diff carries:
- `cosmic/url_test.tl` (347 lines): `safe_href` probes — `"javascript:alert(1)"`,
  `"JavaScript:alert(1)"`, `"data:text/html,x"`, `"//evil.com/x"`,
  `"java\tscript:x"` each yield `raw == "about:invalid"`;
  `"http://ok.example/a b?q=1&r=2"` yields `"http://ok.example/a%20b?q=1&r=2"`;
  `"/x/y?z=1"`, `"mailto:a@b.example"`, `"relative/path"` pass through
  `format` unchanged; `"' onmouseover='alert(1)"` (no scheme, no host) is
  accepted and its `'` survives as `%27`-free text — the codegen half is what
  neutralises it, which the next test pins.
- `cosmic/template/codegen_test.tl`: the url-context test at 98-105 asserts
  `parts%[#parts %+ 1%] = html%.escape%(v1%.raw%)` and that the html-context
  test still emits bare `.raw`.
- `cosmic/template/init_test.tl`: the every-context fixture at 74-97 switches
  its `href` to `cosmic.url.safe_href` and still type-checks.
