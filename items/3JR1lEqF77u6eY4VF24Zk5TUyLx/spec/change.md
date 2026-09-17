`path_anchor` in `_work/direction.tl` consults a source-extension whitelist,
but no case in `_work/direction_test.tl` exercises a slash path with a
non-source extension, so a mutation that lets every extension anchor
survives the test. Add rows to `test_unquoted_anchor_shapes`: `x/y.txt` and
`a/b.json` do not anchor by the path rule alone (note `a/b.json` still
anchors through the dotted-identifier rule when both parts have two or more
characters, so pick stems that isolate the path rule, such as `a/b.txt`),
and `x/y.c` does. Nothing in the helper changes unless a row shows the
whitelist is not consulted.
