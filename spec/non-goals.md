- No call-site conversions. The 61 `from any` sites under this item's
  parent belong to its two sibling items; a validator that lands in the
  same PR as its first consumer proves nothing.
- No change to `json.decode`, `json.decode_object`, `json.decode_array`,
  `literal.parse`, or `Response:json()` — their signatures and return
  contracts are frozen here. `cosmic/json.tl` is not touched.
- No structured `Failure` error record (D24). A path-and-problem string
  is the contract; `check.must` already accepts it.
- No coercion. `shape.number` does not accept `"1"`, and nothing in this
  module converts between types except `shape.integer`'s
  `math.tointeger`.
- No spec derived from a Teal record declaration. Reading `cosmic/_teal_ast.tl`
  to generate a `Spec` from a record is a separate idea and out of scope.
- No new `docs/guides/**` chapter; `cosmic --docs shape` derives from the
  module's own doc comments.
- No `cosmo.*` C-boundary change.
