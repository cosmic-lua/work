Four files.

**1. `cosmic/shape.tl`.** Mirror the `map` branch:

- In `walk`, a new `elseif kind == "integer_map" then` arm directly
  after the `"map"` arm. Non-table → `mismatch(path, "integer_map", v)`.
  A key that is not an integer (`if not (k is integer) then`) →
  `named(path) .. ": expected integer_map, got a non-integer key"`.
  Each value walks through `walk(v, k, spec.of, index_path(path, k))` —
  `index_path` (`cosmic/shape.tl:82`) already renders an integer key as
  `[k]`, which is how the path should read.
- `local function integer_map(of: Spec): Spec` beside `map`
  (`cosmic/shape.tl:219`), returning `{kind = "integer_map", of = of}`.
- The `ShapeModule` field and the `M` entry, in the same positions
  relative to `map` as `map` holds relative to `list`.
- Doc comments: the combinator's own `---` block says the keys need not
  be dense and that this shape reaches `into` only from a Lua-valued
  source (a loaded chunk, or `literal` if it grows integer bracket
  keys), never from JSON.

`Spec` grows no field, and `optional` (`cosmic/shape.tl:236`) already
copies `kind` and `of`, so `shape.optional(shape.integer_map(...))`
works with no change.

**2. `cosmic/shape_test.tl`** (163 lines today). One `test_*` per
behaviour, each called on the line after its `end`:

- a sparse integer-keyed table validates
- a dense one validates too (it is not a `list`, but it is admitted)
- a string key is refused, and the message names the path
- a fractional-number key is refused
- an element that fails `of` is refused, and the path reads `[k]`
- an integer-keyed table nested under `shape.map` validates
- `shape.optional(shape.integer_map(...))` admits nil
- a non-table is refused with "expected integer_map"

**3. `_tool/coverage/report.tl`.** In `read_cov`, replace both casts
with one validation. The spec is a module-level `<const>`:

```teal
local COV <const> = shape.record({
  version = shape.integer,
  hits = shape.map(shape.integer_map(shape.integer)),
})
```

The three existing diagnostics stay, so the order is: `load`/`pcall`
unchanged; `data == nil` → `"empty coverage data"`; validate `data`
against `COV`; on a validation error return it prefixed the way the
module's other errors are; then the `version ~= 1` test →
`"unsupported coverage data version"`, and return the validated `hits`.
`"missing hits table"` is what a `hits: missing` validation error must
still say — keep the explicit nil test above the validation rather than
letting the message change, because
`_tool/coverage/report_test.tl:127` and the gate's own output read it.
Both `-- cast: from any` comments go with their casts; no new cast
appears.

**4. `docs/decisions/d28-shape-combinators.md`.** An amendment, not a
new record ([D26](docs/decisions/d26-decision-records.md)): the facts
D28 rests on are unchanged and its decision still holds — only its
combinator list moves. Add `shape.integer_map` to decision point 2's
enumeration, and one `rejected:` bullet for the key-Spec-on-`map`
alternative, with the reasoning above. Do not restate D28's context or
touch any other section.
