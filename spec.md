# `cosmic --check fmt <directory>` crashes with a raw Lua traceback instead of walking or refusing

## Evidence

Found while building «FyJ2_UFwQ» (`cosmic.http` core); out of that item's
scope (a dispatcher/formatter argument-handling defect, nothing to do
with HTTP).

`--check lint` and `--check types` both accept a directory argument and
walk it; `--check fmt` does not, and instead of a clear error it crashes
with a raw traceback:

```
$ o/bin/cosmic --check fmt cosmic/fetch/
o/bin/cosmic: /zip/tl.lua:1238: attempt to get length of a nil value (local 'input')
stack traceback:
	/zip/tl.lua:1238: in field 'lex'
	/zip/cosmic/format.lua:129: in function 'cosmic.format.format'
	(...tail calls...)
	/zip/_cli/main_handlers.lua:167: in function '_cli.main_handlers.handle_check_format'
	(...tail calls...)
	/zip/_cli/check.lua:93: in function '_cli.check.run'
	(...tail calls...)
	/zip/main.lua:267: in main chunk
```

Reproduced independently (`cosmic/fetch/`, a pre-existing directory
unrelated to any current change) — not caused by any in-flight diff.
`cosmic/format.lua:129` calls into `tl.lua`'s lexer with something that
resolves to `nil` when handed a directory path instead of a file's
source text — the caller (`_cli/main_handlers.lua:167`,
`handle_check_format`) apparently reads the argument as a single file's
contents without checking whether it named a directory first, unlike
`--check lint`/`--check types`'s handlers.

## Direction (not a ready fix — triage this)

Either make `--check fmt` walk a directory argument the same way
`--check lint`/`--check types` already do (consistent, least-surprise
fix), or have `_cli/main_handlers.lua:167` refuse a directory argument
with a clear error before it ever reaches `cosmic/format.lua`/`tl.lua`'s
lexer (minimal fix, if directory-walking `fmt` is out of scope for some
reason not evident from this reproduction). Either way, a raw
interpreter traceback from a CLI misuse is itself worth closing off as
a UX/robustness bug regardless of which resolution is chosen.

## Non-goals

- Not a `cosmic.http` module bug — reproduces on an unrelated
  pre-existing directory, no relation to the item that surfaced it.

## Access

- cosmic-lua/cosmic: read+write.
