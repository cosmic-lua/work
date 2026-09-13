Port the actual `cmd_new` early-refusal check from `cosmic-lua/cosmic`'s
`board` branch (`_work/gitgraph.tl`, PR #1711) onto `cosmic-lua/work`'s
`main`: a root item (no `--parent`) passing `--repo` refuses immediately
with the friendlier message, before generic item validation runs.
