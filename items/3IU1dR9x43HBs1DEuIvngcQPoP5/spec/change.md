In `_make/converge.tl`, `to_the_tree`: when the converging build
fails (either failed-run return) and `was_us` is true, append one
sentence to the refusal: the build ran under the tree's own
`o/bin/cosmic`, which may not match this tree; remove it
(`rm o/bin/cosmic`) and re-run to rebuild from the pin. Keep the
existing first line and verdict detail unchanged (verdict-line
format is frozen); the hint is an addition, never a rewording.

Tests in `_make/converge_test.tl` (234 lines, 266 headroom), in its
existing fixture style: a failing build under `was_us` carries the
hint; a failing build under the pin path (running binary is not the
artifact) does not.
