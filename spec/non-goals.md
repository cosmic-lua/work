Not changing what `--make build`/`--make fetch` print when run directly
by a human or in CI — only `gitboard worktree`'s own wrapping of them
for an orchestrating session. Not touching `--make ci`'s own output
shape.
