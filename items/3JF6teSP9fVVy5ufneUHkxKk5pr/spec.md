## Evidence

Found while confirming «kUVd_PbBu» (the `@field` type-truncation fix)
actually unblocks «HPFM_HEPg»: with the truncation bug fixed, the
correctly-captured type `table<string, string|string[]>` (upstream's
`cosmo.http` `Message.headers` field) still renders wrong —
`{string: {string}}` rather than the accurate `{string: string |
{string}}`.

Root cause is a check-ordering bug in `_types/gentype_render.tl`'s
`convert_type`, independent of `@field` parsing and pre-existing before
«kUVd_PbBu»'s fix:

```
$ sed -n '131,137p' _types/gentype_render.tl
  base = t:match("^(.+)%[%]$")
  if base then return "{" .. convert_type(base) .. "}" end
  local k, v = t:match("^table<([^,]+),%s*(.+)>$")
  if k and v then return "{" .. convert_type(k) .. ": " .. convert_type(v) .. "}" end
  if t:match("|") then
```

The array-suffix check (`^(.+)%[%]$`, "ends in `[]`") runs BEFORE the
top-level union check (`t:match("|")`). For any type shaped `A|B[]` —
a union whose LAST alternative is an array, e.g. `string|string[]` —
the array check's greedy `.+` matches first, capturing `base =
"A|B"` (here `"string|string"`) and wrapping the WHOLE thing as one
array: `{convert_type("A|B")}`, silently discarding the top-level
union structure. `convert_type("string|string")` then dedupes to
`string`, so the final render is bare `{string}` — the "or a plain
string" alternative is gone entirely, not just misplaced.

Reproduced independent of `table<>` nesting, confirming this is
general and not specific to `@field` or to `cosmo.http`: a bare
`@param x string|string[]` renders the same wrong way.

## Direction (not a ready Change — triage this)

The array check needs to defer to the union check when the type's
top-level structure is a union (i.e., check for an UNGUARDED `|` —
one not inside brackets/parens/angle-brackets — before testing for a
trailing `[]`), so `A|B[]` splits into `A` and `B[]` as two union
members the way `t:match("|")`'s own loop (line ~136 onward) already
knows how to convert each `part` of. The existing per-part loop
already calls `convert_type(part)` on each split alternative, which
would correctly turn `string[]` into `{string}` for JUST that
alternative if reached — the loop is fine; only the ordering that
routes control into it is wrong.

Affects any current or future `@param`/`@return`/`@field`/`@type`
annotation shaped `A|B[]` (or more generally, a union with an
array-typed final alternative) across cosmic's generated `.d.tl`
files — worth a `_types/gentype_render_test.tl`-shaped regression
(or check whether such a file already exists and add there) pinning
`string|string[]` → `string | {string}`, not `{string}`.
