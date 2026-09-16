Add a test that renders every command line appearing in the tool's own prose —
`gitboard help <topic>` and `gitboard help <verb>` output, the brief templates
in `_work/brieftext*.tl`, and the work skill's markdown in cosmic-lua/cosmic —
and fails when a line names a verb that does not exist, a flag the verb does
not accept, or a verb the tool marks deprecated.

The check does not need to EXECUTE the lines. Parsing each one to a verb plus
a flag set and validating that pair against the same option tables the CLI
already builds is enough to catch every instance measured below, and it stays
fast and hermetic.

Scope the markdown half however is practical: the work skill lives in another
repository, so this may be a `_build`-style ratchet over the templates and
help topics here, plus a documented rule that the skill stops restating verb
mechanics at all. Whoever takes this decides which; the templates and help
topics in this repository are the part that must be covered.
