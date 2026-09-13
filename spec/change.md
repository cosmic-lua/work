`cosmic/check.tl:167`: reword the trailing `-- throws:` comment to state
why `swap_members` may throw (per D23: `check` module functions are
permitted to throw) without citing the decision record by number — e.g.
`-- throws: check may throw; rethrows body's error after restoring members`.
