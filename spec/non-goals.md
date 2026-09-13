No semantic edits ride along: no renames, no assertion changes, no test
added or removed, no reflow, no comment rewrites. The 23 trailing
`print("all … tests passed")` lines in scope now print before the cases
run rather than after; they are not this batch's to touch — leave them
exactly as they are. No `*/testdata/*` file — fixtures belong to the
tests that read them, and `_make/testdata/assets/note_test.tl` is one.
No `_cli/citations_test.tl` — 3IVAhnTj owns it, and folding its fix in
would put insertions into a deletions-only diff. No file outside this
batch's scope — the other six batches are file-disjoint on purpose. No
change to `cosmic/test.tl`, `_tool/seam.tl`, `_tool/discover.tl`, or the
`call-after-define` lint (retiring it is 3IOCdvXF; it already passes on
a runner-mode file). No testrun or report change (3IOCdZCA, landed). No
pin bump — 3IU62YqO landed as #1450 and 3IUJSV7e as #1457.
