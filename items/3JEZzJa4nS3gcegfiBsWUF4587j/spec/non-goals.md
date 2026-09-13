- Nothing in `cosmic/http/` changes. If a needed `Response` method is
  missing, that is a child of this item, not a reach into the server.
- No htmx JS asset, no CSRF, no session: the guide child.
- No `hx-*` attribute builders for templates: attributes are text in a
  `.tmpl`; the template module's `attr` context already types them.
