# AGENTS.md

`CLAUDE.md` is a symlink to this file. Edit this file only.

## Repository

This repository contains cosmic's work board and the `gitboard` machinery.
Source changes land on `main`; live board state lives on
`refs/heads/state`. Never mix the two.

- `_work/`: Teal modules and tests
- `cmd/gitboard/`: binary entry point
- `docs/design/`: storage and ordering contracts
- `experiments/native/`: semantic and migration campaigns
- `bin/cosmic`: pinned build runtime
- `o/`: generated output; never commit it

The current board format, publication protocol, and operator recovery
procedures are contracts. Read the relevant design document and
`gitboard help <topic>` before changing them. Do not restate that doctrine
here.

## Working safely

Use an isolated clone or worktree. Do not share a stash or build directory
with another session.

Operate board state only through `gitboard`. Never hand-edit item data or
push `refs/heads/state` directly. Product-source changes use a branch and
pull request against `main`.

Keep changes inside the requested scope. Record adjacent findings as board
items rather than widening a diff. Preserve unrelated changes already in a
working tree.

## Code

Source is Teal (`.tl`), with two-space indentation and LF endings. The
repository root is the module root. A leading underscore marks internal
code. Keep files at or below 500 lines.

Use `snake_case`; include units in names such as `timeout_ms`; prefix
predicates with `is_`. Public functions need `---` documentation with
`@param` and `@return`.

Fallible value functions return `T | nil, string`; fallible effects return
`boolean, string`. Do not silently discard errors. A deliberate throw,
assertion, or process exit must carry the repository's justification
annotation.

Tests live beside their source as `*_test.tl`. Add a focused regression for
each behavior change.

## Validation

Prefer the narrowest useful checks while iterating:

```sh
bin/cosmic --make fetch
bin/cosmic --make build
bin/cosmic --make test _work/<file>_test.tl
```

Before pushing, run:

```sh
bin/cosmic --make ci
```

Read the final `ci: PASS` or `ci: FAIL` verdict; do not hide its exit status
behind a pipe. CI owns the full `.cosmic-coverage` floor. Change only
affected coverage rows, with measured evidence; never regenerate the whole
file locally.
