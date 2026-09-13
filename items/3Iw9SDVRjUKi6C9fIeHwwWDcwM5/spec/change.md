`_work/brief.tl`'s `product_root()`: when `dirname(dirname($GITBOARD_DIR))`
does not contain a `bin/gitboard` file (`fs.is_file(candidate ..
"/bin/gitboard")`), it is not a real product checkout — fall back to
searching upward from the CURRENT WORKING DIRECTORY (the orchestrator's
own checkout, which is always a real product repo — that's what
`bin/gitboard` was invoked from) for the nearest ancestor directory
containing `bin/gitboard`, the same way a project root is normally
found. Return `""` (today's already-handled "leave `<PRODUCT_ROOT>`
for the caller to fill" case) only if neither the dirname-dirname
guess nor the cwd search finds one.

Keep the existing dirname-dirname computation as the FIRST attempt
(cheap, correct for the common cold-start case) — this is an added
fallback, not a replacement.

`_work/brief_test.tl` or `_work/brief_rework_test.tl` (check current
headroom in each — `brief_test.tl` was at 498 lines as of 2026-09-06,
prefer `brief_rework_test.tl` if it's tighter): add one test setting
`GITBOARD_DIR` to a sibling-shaped path (not ending in `o/board`) with
a real `bin/gitboard` reachable only via the cwd fallback, asserting
the emitted brief's `PRODUCT_ROOT` resolves to the real checkout, not
the wrong dirname-dirname guess.
