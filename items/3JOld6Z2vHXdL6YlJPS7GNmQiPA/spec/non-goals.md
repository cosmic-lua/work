Not changing what a valid pattern matches, not changing the metavariable
syntax, and not changing any other refusal's wording.

Not addressing the separate discoverability problem that `--find` takes a
Teal EXPRESSION rather than a regex or literal — a reviewer this session read
`find: refused: <pattern>:1:1: invalid token '\'` as a broken regex engine.
That is worth its own item; this one is scoped to the crash.
