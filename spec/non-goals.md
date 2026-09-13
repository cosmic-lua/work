`parse_atom` (`_cli/returns.tl:150-165`) still reads a named alias as never
admitting nil, so `local type Maybe = string | nil` + `return nil` counts as a
lie (measured in the same probe: `control_local_type: lines=3`). Different
rule, different item.
