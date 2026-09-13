Not landing `4zwL_sOKR` or `0Svo_ZeTH`'s own cast removals — those are
separate items, unblocked once this lands (each still needs its own
pin bump verified and cast-removal diff). Not auditing every other
`@type`-tag annotation in `definitions.lua` for the same truncation —
this item fixes the parser; a sweep for other affected bindings, if
any beyond `unix.E`/`unix.SIG`/`unix.CAP`, is separate follow-on work.
