Make `_work/tail.tl`'s `resolve_glob` ambiguity refusal join the matched
**tails**, not the full ids, so both new paths (and the pre-existing
`tail.resolve` path) render the identical refusal shape for the same
input. Add a test case (in `_work/tail_test.tl` or `_work/gitboard_test.tl`,
wherever the existing ambiguity-refusal test already lives) that an
ambiguous tail refuses with the same message text regardless of which
path (cache hit vs. glob) resolves it.
