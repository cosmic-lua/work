A bare, unquoted `{{js .x}}` slot (`var x = {{js .x | cosmic.js.safe}}`)
stays unchecked: nothing scans the surrounding script, and the escaper cannot
tell a string body from an expression. State it in the doc; do not add a
quote-scanning parser. `cosmo.EscapeLiteral` is a C contract and is not
changed. Template-literal safety is a side effect, not a documented context.
