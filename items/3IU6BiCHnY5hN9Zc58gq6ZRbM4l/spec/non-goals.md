No semantic edits ride along: no renames, no assertion changes, no
test added or removed, no reflow, no comment rewrites. No file outside
this batch's scope — the other six batches are file-disjoint on
purpose and two of them must never touch one file. No change to
`cosmic/test.tl`, `_tool/seam.tl`, `_tool/discover.tl`, or the
`call-after-define` lint (retiring it is 3IOCdvXF; it already passes
on a runner-mode file). No testrun or report change (3IOCdZCA). No pin
bump — that is 3IU62YqO, this item's blocker.
