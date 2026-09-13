Not `gVi7_9Ne8`'s own `fd2`-narrowing diff — that stays scoped to
`cosmic/net/init.tl` and resumes once this pin bump lands. Not a
general audit of every other binding this pin bump might also touch —
`bin/cosmic --make ci` after the bump is the mechanical check for
regressions; anything it doesn't catch is a separate finding.
