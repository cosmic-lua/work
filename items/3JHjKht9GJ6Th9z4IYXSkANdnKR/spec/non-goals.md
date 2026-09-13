No code changes and no README rewrite beyond the one line: the README's
`(no items/ directory — every item is a git ref, not a file)` line
(`grep -n "every item is a git ref" README.md`) is true until the migration
runs and is rewritten by the retire child. The record does not restate D49
or D47; it names them. The single-head guide under `experiments/` is left
as it is — the retire child removes it.
