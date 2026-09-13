`_cli/returns.tl`: extend the fallible-returns scan to a `macroexp`
identifier that opens a body (the same tell #1616 uses in
`_cli/nilreturn.tl`: `macroexp` followed by a name, or `= macroexp(`
in a record field), reading its declared return list through the
shared grammar. Add a case to the lint's test corpus: a macroexp with
three slots past the error is diagnosed at its line; a two-slot
macroexp and `local macroexp = 1` are not.
