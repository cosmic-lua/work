Bump `bin/gitboard.pin` (both lines) to the cosmic-lua/work release built
from the merge of the last format-6 engine child (`migrate6`, the
connector plan and the contention scenarios all landed), the way
cosmic#1855 did for format 5, and verify the way the trust root does:
`rm -rf o/bootstrap/gitboard o/bootstrap/gitboard.pin && bin/gitboard
help | grep -c migrate6` prints 1, `bin/gitboard help publish | grep -c
-- --plan` prints at least 1, `o/bootstrap/gitboard fsck` on a fresh
clone of the live (still format-5) board reports ok, and
`_build/gitboard_pin_test.tl` passes.

### Completion recorded 2026-09-14

Completed elsewhere and independently checked during the post-cutover refresh.
cosmic-lua/cosmic#1858 merged as
90661833b66df92d3a8d9125f3f036f3746f5056:
https://github.com/cosmic-lua/cosmic/pull/1858

The pin now selects cosmic-lua/work release 2026-09-14-7f88ef3, built
from work#171 (7f88ef302822dc047b00576ea72707c892658584), with SHA-256
c4ae92bf163b78a7dbd65921ee70a163970b8208307cf5d12f1ef5e6b19da4a2.
Both pin fields were checked directly on Cosmic main. PR #1858 records
successful fsck using the pinned binary. A separate read-only audit here
using the validated format-6 implementation also passed: cache agrees
with refs; ok (1448 items).

The original pre-migration format-5 check above is historical: activation
preceded the consumer pin, as required by the final single-release design.
This completion records the landed change, not a newly performed pin test
or a new implementation/review cycle. Remaining live workflow and archive
freeze verification is tracked by the cutover item Ocke_igKh.
