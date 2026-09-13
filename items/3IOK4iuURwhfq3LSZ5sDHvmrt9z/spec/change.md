**1. `_types/gentype_inline.tl` (new file).** `cosmo.ParseParams` is annotated
`---@return { [1]: string, [2]: string? }[] params` — the exact shape
`cosmic/url.tl` casts to — but `convert_type` in `_types/gentype_render.tl`
renders it `any`, because its inline-struct guard (`if t:match("^{.*:") then
return "any" end`, line 68 today) fires before the `[]`-suffix branch below it
and nothing maps a positional struct. Put the two missing conversions in a new
shard rather than in `convert_type` itself: `wc -l < _types/gentype_render.tl`
is 486, so the 500-line cap leaves 14 lines and the branches do not fit.

Export one function:

```teal
--- @param t string The LuaLS type
--- @param convert function(string): string convert_type, for member types
--- @return string | nil The Teal type, or nil when t is not one of these forms
inline_array: function(t: string, convert: function(string): string): string | nil
```

It recognises exactly two forms and returns `nil` for everything else:

- **a bracketed struct array** — `t` matching `^({.*})%[%]$`: return
  `"{" .. convert(inner) .. "}"`.
- **a positional struct** — `t` matching `^{%s*%[1%]%s*:%s*(.+)}$`: split the
  body on commas, strip each member's `[n]:` label and its trailing `?`,
  `convert` each, and return `"{" .. elem .. "}"` when every member converts
  to the SAME Teal type. Return `nil` when they differ — Teal has no tuple
  type, so a mixed positional struct has no honest rendering and must keep
  falling through to `any`.

**2. `_types/gentype_render.tl`.** `require` the shard and call it from
`convert_type` immediately BEFORE the `if t:match("^{.*:")` guard, passing
`convert_type` itself as the callback; return its result when non-nil. Order
matters: after the guard the form is already `any`. Three lines; the file ends
at 489 or below, which is an Acceptance command.

**3. `_types/gentype_inline_test.tl` (new file).** Cover both recognised forms,
the mixed-member case that must stay `nil`, and a plain inline struct
(`{ name: string }`) that must stay `nil`. House test form — one `test_*`
function called on the line after its `end`. A new file, not an addition to
`_types/gentype_test.tl`: that file is 494 lines, 6 under the cap.

**4. `cosmic/url.tl`.** With the declaration concrete, both casts are
redundant: drop `as {{string}}` and the trailing `-- cast: from any` on lines
64 and 204. The file's third cast (line 54, `-- cast: %x%x is a hex pair`)
stays.

**5. `cosmic/signal.tl`.** Lines 259–261 cast `sigaction`'s second, third and
fourth returns "from any", but the generated declaration has been concrete for
some time — `o/_types/types_gen/cosmo/unix.d.tl` declares `sigaction:
function(...): function | integer | nil, integer, Sigset, string, Errno`. The
three casts narrow nothing. Verified 2026-08-25: replacing the block

```teal
  local phandler = prev as (function | integer) -- cast: from any
  local pflags = prev_flags as integer -- cast: from any
  local pmask = prev_mask as Sigset -- cast: from any
  return {handler = phandler, flags = pflags, mask = pmask}
```

with `return {handler = prev, flags = prev_flags, mask = prev_mask}` and
running `bin/cosmic --check types cosmic/signal.tl` prints
`Type check passed: cosmic/signal.tl`. Make that replacement. The file's other
two casts (line 250 `-- cast: handler union`, line 291 `-- cast: record built
incrementally`) stay.

**6. `_build/casts_baseline.tl`.** Run exactly the regen command the gate's
failure message prints (`bin/cosmic --make run _build/casts.tl --baseline`) and
commit the result; same for `.cosmic-coverage` if `--make ci` asks for it. Read
the regenerated diff before committing: only the rows this change touches may
move — a lowered row anywhere else means the regen ran against a partial tree,
so re-run it, never commit it.

**Blast radius, measured.** Prototyped 2026-08-25 and diffed
`o/_types/types_gen` before and after a build with the change: exactly one
declaration line moves,
`ParseParams: function(paramstring: string): any` →
`ParseParams: function(paramstring: string): {{string}}`. No other generated
declaration changes.
