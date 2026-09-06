## Evidence

Found 2026-09-06 building board item `4zwL_sOKR` (land `errno.tl`'s
`unix.E`/`unix.SIG` constant-lookup cast removals once cosmopolitan#391
pins). `cosmopolitan#391` genuinely lands `unix.E`/`unix.SIG` as
`--- @type table<string, integer>`-annotated fields (confirmed:
`3p/cosmos/cosmos_pin.tl` bumped to `2026.09.06-e748d6a1e`, a release
descending from that commit, `bin/cosmic --make build` run against it),
but the GENERATED `o/_types/types_gen/cosmo/unix.d.tl` shows `E: table`
/ `SIG: table` — bare `table`, not `{string: integer}`.

Root cause: `_types/gentype_parse.tl`'s `TYPE_TAG` regex
(`^%-%-%-%s*@type%s+([%w_%.]+)`) has no `<`, `,`, or `>` in its
character class, so a `--- @type table<string, integer>` annotation on
a module FIELD is truncated to the bare head token `table` before any
generic-type parsing runs. The conversion logic to turn
`table<K, V>` into the Teal map-type `{K: V}` already exists
(`_types/gentype_render.tl:134`, `convert_type`) and is exercised for
`@param`/`@return` annotations (`_types/gentype_return_test.tl`), but
is never reached from `@type`-tag field parsing — `gentype_test.tl`
tests `convert_type` in isolation but never through a `@type` module
field.

Confirmed empirically: with the pin bumped, `unix.E["ENOENT"]` assigned
to a declared `integer | nil` fails type-check
(`got <any type>, expected integer | nil`), and the same fails
returning it from a function typed `(): integer | nil`.

This blocks at least two other board items identically: `4zwL_sOKR`
(this one; `unix.E`/`unix.SIG`) and `0Svo_ZeTH` (`unix.CAP`, same
`table<string, integer>` shape, cosmopolitan#392) — both cannot close
their cast-removal `## Change` without this fix, since the type they'd
index into is `table`, not a real map type.

## Change

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

## Non-goals

Not landing `4zwL_sOKR` or `0Svo_ZeTH`'s own cast removals — those are
separate items, unblocked once this lands (each still needs its own
pin bump verified and cast-removal diff). Not auditing every other
`@type`-tag annotation in `definitions.lua` for the same truncation —
this item fixes the parser; a sweep for other affected bindings, if
any beyond `unix.E`/`unix.SIG`/`unix.CAP`, is separate follow-on work.
