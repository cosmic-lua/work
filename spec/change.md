Reword each of the four sites above to describe the current mechanism
(`--check lint`'s `cast-justify` rule in `_cli/cast_lint.tl`, per-file,
via `cosmic.ast` parsing, no ceiling/exactly-one-match language) instead
of the deleted `_build/casts_test.tl`/lexer-based `cast_lines`. For
`3p/tl/tl_patch/cast.tl:73` specifically: read `«NPTx_ycXD»`'s own
already-landed (or in-review) rewording of the adjacent stale reference
in the same file first, and match its style/approach (state the
invariant directly rather than naming whichever module currently plays
the role, per `docs-style`'s guidance that a JUSTIFICATION comment
should be self-contained, not a pointer to a file that can go stale
again) — don't duplicate work if `«NPTx_ycXD»` already touches this
exact line.
