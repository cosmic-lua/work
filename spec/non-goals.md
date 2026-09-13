No semantic edits ride along: no renames, no assertion changes, no
test added or removed, no reflow, no comment rewrites. No
`*/testdata/*` file — fixtures belong to the tests that read them. No
file outside this batch's scope — the other six batches are
file-disjoint on purpose. No change to `cosmic/test.tl`,
`_tool/seam.tl`, `_tool/discover.tl`, or the `call-after-define` lint
(retiring it is 3IOCdvXF; it already passes on a runner-mode file).
No testrun or report change (3IOCdZCA, landed). No pin bump —
3IU62YqO landed as #1450.
