- no change to `3p/tl/tl_patch.tl` — the honest-`math.tointeger`
  declaration is measured to buy nothing and is retired above; the
  upstream report is a separate item.
- no new `to_integer` helper, in `cosmic/string.tl` or anywhere. The
  measurement found no site that a helper would fix.
- no change to the other 66 `math.tointeger` sites — each is walked in
  the table above and each is safe.
- `cosmic/quicksand/proxy/rules.tl`'s `parse_rule: function(key:
  string): string, integer` returns nil in slot 2 by design and its
  declared type says otherwise; `match`'s `port: integer` parameter has
  the same lie. Both are real and both are OUT of this slice — filed
  as their own item.
- no change to `serve.tl` or `dial.tl`: the fix belongs at the parse
  boundary, and both callers already handle a nil parser return.
- `cosmic/sse.tl:145` is not touched — nil is that field's existing
  "unset" value and every read guards it.
