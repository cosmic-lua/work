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
