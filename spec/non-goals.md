Not changing `-i`'s behavior (always forces the REPL, tty or not) —
that stays a way to force interactive mode over a pipe if anyone
relies on it. Not touching `cosmo.repl`'s own line-by-line semantics
for the genuinely-interactive case.
