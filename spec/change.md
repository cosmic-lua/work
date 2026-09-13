Add `cosmic/shape.tl` (public API `cosmic.shape`), `cosmic/shape_test.tl`,
`cosmic/shape_example.tl`, and the decision record `docs/decisions/d28-<slug>.md`.
Convert no call sites — the sibling items own those.

**The API.** A combinator that builds a runtime `Spec`, plus one
generic entry point that validates and hands the value back typed:

```teal
local record Spec end          -- opaque to callers

shape.string:   Spec
shape.number:   Spec
shape.integer:  Spec
shape.boolean:  Spec
shape.any:      Spec
shape.list:     function(of: Spec): Spec
shape.map:      function(of: Spec): Spec
shape.record:   function(fields: {string: Spec}): Spec
shape.optional: function(of: Spec): Spec

shape.into: function<T>(value: any, spec: Spec): T | nil, string
```

`into` walks `value` against `spec` and returns `nil, <path>: <problem>`
on the first mismatch, or the value itself typed as `T`. It returns the
SAME table, not a copy.

**Combinators, not a table of type-name strings.** A spec written as
`{a = "string", b = "number?"}` is data the checker cannot check: a
misspelled type name or a stray key is a runtime error at best and a
silently-skipped field at worst. Every combinator above is a typed
value, so `shape.strng` and a spec key that is not a `Spec` are compile
errors. That is the tradeoff the decision record carries, and its
`rejected` section must state the string-table form and the cost of
picking combinators (verbosity at every spec).

**T comes from the caller's annotation.** Verified against the pinned
release (`bin/cosmic --check types` on a scratch file, 2026-08-25):
three call shapes infer `T` and one does not.

```teal
-- library: a function declared `T | nil, string` returning it directly
return shape.into(raw, SPEC)                              -- works
-- a local with its error
local m, err: Meta | nil, string = shape.into(raw, SPEC)  -- works
-- tests
local m: Meta = check.must(shape.into(raw, SPEC))         -- works
local m = check.must(shape.into(raw, SPEC))               -- FAILS:
                          -- "cannot infer declaration type"
```

The module's doc comment must show all four lines, the failing one
included with the error it produces. Two sibling items convert 61 sites
against this API and will hit the fourth shape.

**Settled semantics, to state in the module doc comment and pin with a
test each:**
- Extra keys the spec does not name are IGNORED. A decoded payload that
  grows a field must not start failing.
- A missing key and an explicit JSON `null` are the same thing: both
  decode to nil, and `shape.optional` is what admits either.
- `shape.integer` accepts a number with no fractional part and stores
  `math.tointeger` of it; a fractional number is a mismatch.
- `shape.map(of)` checks every value against `of` and accepts any string
  key; `shape.list(of)` checks `ipairs` order and rejects a non-list.
- `shape.any` accepts any non-nil value; wrap it in `shape.optional` to
  admit nil.
- Errors are plain strings carrying a dotted path with `[i]` for list
  indices (`"rows[2].silent_bugs: expected number, got string"`), the
  first mismatch only. No structured `Failure` record.
- Validation is recursive and total over what the spec names: nothing is
  checked shallowly and nothing below a named field is left unchecked.

**The record.** `docs/decisions/d28-<slug>.md` in the four-section form
(`skills/decide/SKILL.md`), H1 exactly `# D28 — <claim, lowercase>`, and
the derived table in `docs/decisions/README.md` gains its row — that
file is 64 lines today and `D27` is its last row, so the new row is
appended.
