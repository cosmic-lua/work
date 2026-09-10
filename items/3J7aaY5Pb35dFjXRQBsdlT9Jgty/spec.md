## Change

Prepare the pinned parser boundary for a later `--diff` activation. In
`_cli/parse.tl`, add dormant `Options.diff: string` and assign
`opts.diff = p.values["diff"]`. Do not add the flag to `_cli/args.tl`, read the
field from a caller, advertise it, dispatch it, or change `_make/startup.tl`.


`git grep -n '"_cli.args", "_cli.parse", "_make.startup"'
_build/make_boundary.tl` names all three in the frozen pre-install capsule.
Landing this record shape first allows a later release/pin to make the field
visible while generation 1 compiles the activation change. Touch only
`_cli/parse.tl` and its focused test if a new assertion is needed; stay under
25 changed lines. Run the cold-build boundary test in addition to the normal
gate.

## Non-goals

No flag declaration, help, startup precedence, handler, archive code, pin
change, or temporary user-visible placeholder command.

