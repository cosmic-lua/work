Not a general coverage-tooling audit — scoped to this one pin bump and
its regen. Not implementing a second copy of the guard anywhere in the
`board` branch's own tree — there is nowhere to put one: the branch
owns no `_make/`, no `cmd/cosmic`, no coverage-policy source of its
own; the guard reaches `board` only via `bin/cosmic.pin`.
