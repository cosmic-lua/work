Redeclare `re.Regex:find`'s return shape so slot 2 does not admit both
an integer offset and a string error simultaneously. This is a
distinct C function (`LuaReRegexFind`) from the `search`/`match`
captures' `LuaReRegexSearch`, so it is not automatically fixed by
their diff — land as its own change, though the shape decision (how
to represent "no error" vs "an error" alongside a success payload)
should match whatever the `re.Regex:search` capture (`3IiuEB99`)
settles on for consistency across `cosmo.re`.
