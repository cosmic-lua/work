No fixture restructuring: no per-case root, no setup/teardown helper
pair, no `temp_dir` call. The cases keep their shared `root` and the
case count stays 11. No assertion changes, renames, reflow or comment
rewrites beyond the one stranded blank line named above. No change to
any other file — `cosmic/fs/glob_test.tl` is the whole diff. No change
to `cosmic/test.tl`, `_tool/seam.tl`, `_tool/discover.tl`, or the
`call-after-define` lint.
