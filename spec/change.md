In `_types/gentype_parse.tl`, extend the `@type`-tag field path to
route through the same generic-type conversion `@param`/`@return`
already use: widen `TYPE_TAG`'s character class to admit `<`, `,`,
`>`, and whitespace inside the angle brackets (or otherwise capture the
full annotation token, e.g. `table<string, integer>`, rather than only
its head word), then pass the captured type string through
`_types/gentype_render.tl`'s existing `convert_type` before emitting
the field's declared type, exactly as the `@param`/`@return` path
already does.

Add a test to `_types/gentype_test.tl` (or `gentype_parse_test.tl` if
splitting is warranted by the file cap) asserting that a `--- @type
table<K, V>` field annotation on a definitions-style module round-trips
to the Teal map type `{K: V}` in the generated declaration — the
missing coverage this bug slipped through.

Gate with `bin/cosmic --make ci`.
