One commit, deletions only in `cosmic/**/*_test.tl`: for each
`local function test_<name>` in a file, delete the later line that is
exactly `test_<name>()` (trailing whitespace tolerated, nothing
else). A file where any `test_*` deletion candidate does not match
that exact shape, or where a `test_*` name appears in any non-call
position, is skipped whole and named in the PR body as left-legacy.
Scripting the walk is fine (the discovery lexer or a line scan);
committing the script is not part of this slice.
