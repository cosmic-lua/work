Bump `bin/gitboard.pin` (both lines) to the cosmic-lua/work release built
from the merge of the migrate6 child, the way cosmic#1855 did for format 5,
and verify the way the trust root does: `rm -rf o/bootstrap/gitboard
o/bootstrap/gitboard.pin && bin/gitboard help | grep -c migrate6` prints
1, `o/bootstrap/gitboard fsck` on a fresh clone of the live (still
format-5) board reports ok, and `_build/gitboard_pin_test.tl` passes.
