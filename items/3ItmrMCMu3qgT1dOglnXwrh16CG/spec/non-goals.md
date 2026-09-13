Not proposing a fix yet — no patch design here has been tried against
`--check types` across the tree. Not the sibling item's zero-return
case (`cosmic/shm.tl:146,171`), which is a distinct root cause already
resolved in `3IpXih2Xjo6tszK6RmNnG3pQYHj`. Not `cosmic/_teal_engine.tl:256`
(filed separately: distinct nominal-vs-structural mismatch, not a
failure-arm mistyping).
