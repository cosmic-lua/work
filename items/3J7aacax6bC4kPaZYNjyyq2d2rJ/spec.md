## Change

Ready when all of these print `READY`:

```
test -f _tool/surface_diff.tl -a -f _tool/surface_archive.tl && echo READY
bin/cosmic -e 'local fs=require("cosmic.fs"); local p=require("cosmic.proc").interpreter(); local a=assert(require("cosmic.zip").open(p)); local s=assert(a:read(".tl/_cli/parse.tl")); assert(a:close()); print(s:match("\n%s+diff:%s+string%s*\n") and "READY" or "WAIT")'
```

Add `_cli/diff.tl` and `_cli/diff_test.tl`; add the `--diff BINARY` flag to
`_cli/args.tl`, populate it in `_cli/parse.tl`, exclude `opts.diff` from
`_make/startup.tl`'s `effective_make`, dispatch it in `cmd/cosmic/main.tl`, and
document it after `--docs` in `sys/help.md`. These are the only production
files allowed. Do not edit `cmd/cosmic/embed_gen.tl` or reclaim dispatcher
lines: current main is 244 lines.

The handler resolves the running executable with `cosmic.proc.interpreter()`,
loads OLD and self through `_tool.surface_archive`, compares/renders through
`_tool.surface_diff`, writes the complete report, and returns 1 when any delta
is breaking, 0 otherwise. Usage/archive/extraction failures return 2 with one
concise diagnostic. OLD is data and is never executed. `--diff OLD --make
build` follows normal fixed command precedence and must not initialize a
project build.

Tests cover parsing, removed/retyped/added-only/module-removed results, exact
rendered output and exits, malformed OLD, startup precedence, and a real
self-binary comparison. Touch focused parser/startup tests only where needed.
Keep the entire change between 220 and 320 lines across at most nine files;
bounce if archive or comparison behavior must change. Run the cold-build test
and full gate.

## Non-goals

No `_cli/upgrade.tl`, baseline/ratchet, gone wrappers, consumer scan, source or
pin rewrite, network access, or unrelated CLI cleanup.
