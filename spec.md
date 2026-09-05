## Evidence

Found by the builder of `3ItQ4xOmSviLE8A967ILbjXBhTY` («LbjX_BhTY», "cosmic.flags: a
positional that begins with a dash...") while implementing that item's Change 5,
which asserts "`cosmic --docs -- '--recipe'` already reaches [the handler] with the
query intact (the parser strips the terminator)." That premise is false against the
current tree.

Reproduced 2026-09-05 against a tree built from `main`:

```
$ o/bin/cosmic --docs -- "--recipe"
cosmic documentation
Modules:
  cosmic.ansi ...
  ...
exit=0
```

`--docs`'s query argument is silently dropped — not a "not found" error, the full
module index prints as if `--docs` had been given no argument at all. `cosmic.flags`
itself handles `--` correctly (`cosmic/flags/getopt_test.tl:81` pins
`getopt.parse({"-v", "--", "-h", "file.txt"}, "vh")`); the drop happens upstream, in
the CLI dispatcher's own pre-scan.

`cmd/cosmic/main.tl`'s `parse_args()` (~lines 132–174) walks the raw `arg` looking
for where cosmic's own options end and a script name begins, and treats the FIRST
bare `--` it meets as that boundary:

```
if a == "--" then script_idx = i + 1; break
```

regardless of whether that `--` was meant to terminate `--docs`'s own OPTIONAL
argument rather than end cosmic's own option list. So the `cosmic_args` table
handed to `flags.parse` ends up as just `{"--docs"}` — `"--recipe"` is excluded via
the `script_idx` machinery before `flags.parse` ever sees it. `_cli/args.tl`'s
`resolve_optional_arg` (the space-separated-optional-arg fallback) independently
also bails when the next raw-`arg` token is `--`, for the same reason.

The one form that already works is `--docs="--recipe"` (verified: reaches the query
intact) — only the space-separated-plus-`--`-terminator form is affected.

A regression test already exists on the LbjX_BhTY branch, added while chasing this:
`_cli/main_handlers_test.tl::test_docs_query_after_dash_dash_terminator`, currently
failing (`o/bin/cosmic --make test _cli/main_handlers_test.tl` → 16 passed, 1
failed). It is not on `main` — it lives only in the unpushed commit on LbjX_BhTY's
branch (`3ItQ4xOm`, worktree `/home/user/wt/LbjX_BhTY`) and can be ported verbatim.

## Change

Fix `cmd/cosmic/main.tl`'s `parse_args()` pre-scan (and/or `_cli/args.tl`'s
`resolve_optional_arg`, whichever the actual fix lands in) so that a `--` meant to
terminate an OPTIONAL-argument flag's value (`--docs`, or any flag `_cli/args.tl`
declares with an optional argument) is not mistaken for the end of cosmic's own
option list when a value follows it. Port
`_cli/main_handlers_test.tl::test_docs_query_after_dash_dash_terminator` from
LbjX_BhTY's branch (`git show 3ItQ4xOm:_cli/main_handlers_test.tl` once that branch
is reachable, or re-derive it from this spec's reproduction) and get it green. Add a
one-line comment at the pre-scan's `if a == "--"` branch noting that it can shadow an
optional-arg flag's own terminator, so the next person tracing this does not have to
re-derive it (the LbjX_BhTY builder spent roughly 15 tool calls pinning the cause
down for lack of exactly this note).

## Non-goals

`cosmic.flags`/`cosmic/flags/parse.tl` itself — already correct, per
`getopt_test.tl:81`. Any change to `LbjX_BhTY`'s own scope (items 1–4 of its Change,
already implemented and unaffected by this bug).
