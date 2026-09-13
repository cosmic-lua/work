`bin/gitboard`: the two `case` patterns become `*cosmic-lua/work |
*cosmic-lua/work.git` (drop the leading `/`), which matches both
transports and still refuses `someone-else/work`.
`_cli/gitboard_root_test.tl`: one more case,
`test_prefers_an_ssh_sibling_work_clone`, with origin
`git@github.com:cosmic-lua/work.git` → the sibling path.
