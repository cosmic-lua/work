## Change

New `_cli/rewrite.tl`, a `--rewrite` verb wired into the dispatcher the
same way `_cli/lint.tl`/`_cli/format.tl` already are (grep
`_cli/lint.tl`'s own registration site at pull time and mirror it —
name the exact file/line found). Consumes `cosmic.ast.node`/`.walk`/
`.match`/`.rewrite` (the four sibling items under this outcome; take
them first) as a thin CLI layer, the same relationship `_cli` already
has with `cosmic.fs`:

```
cosmic --rewrite '<pattern>' <path>...    # search: print each match's span
cosmic --rewrite '<pattern>' '<repl>' --fix <path>...   # apply in place
```

`<path>...` accepts multiple files or directories in ONE process
invocation — this is not a convenience, it is the item's main
performance requirement, measured directly this session
(`docs/design/ast-rewrite/README.md`, "Performance notes"): fixed
per-invocation overhead (process boot + `require`s) is ~11-12ms
regardless of file size, real per-file work for a typical file is a
few ms, and running 50 real files as 50 separate `bin/cosmic`
invocations measured 738ms (~14.8ms/file) against 281ms (~5.6ms/file)
for the same 50 files in one process — 2.6x, purely from amortizing
that fixed cost. A directory argument expands to every `.tl` file
under it via `_make`'s existing project-file traversal (reuse it —
grep `_make` for the verb that already answers "which files belong to
this project" for `--make lint`/`fmt` at pull time and call the same
one; do not write a second, separately-maintained file-walk).

Search mode prints `file:y:x-yend:xend  matched text` per hit, one line
per match, files processed in argument order, hits within a file
sorted by position (as `cosmic.ast.rewrite.find_all` already
guarantees). `--fix` mode requires the replacement argument, writes
each file's rewritten content back only if `cosmic.ast.rewrite`
returned an ok (formatted, reparsed-clean) result, and reports refused
hits (comment-loss) to stderr with file:position, per the mechanism
`cosmic.ast.rewrite` already implements — this verb does not
re-implement that decision, just surfaces it.

## Non-goals

No multi-pass/fixpoint application in this item (depends on a fixpoint
mechanism not yet built — see the rewrite item's non-goals). No dry-run
diff rendering beyond the plain per-hit line above; a nicer unified-diff
`--check` mode is a reasonable follow-up, not required here.

## Acceptance

Re-run this session's dogfood as the acceptance check: `cosmic
--rewrite 'cosmo.$F($$$ARGS)' _make _cli _tool _types _docs _perf cmd`
(re-measure the exact file count and match count at pull time — this
session measured 304 files, 3 real call sites, all three carrying
rationale comments; re-confirm the count still holds on the current
tree) should complete in one process and report exactly those call
sites, not the ~30-file noise a plain grep for `cosmo\.` produces (most
of that noise being comments and `*_test.tl` files, per the same
session's findings).
