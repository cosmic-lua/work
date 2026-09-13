Audit `_work/*_test.tl` for test CASES (not fixture helpers — those are
already being consolidated separately, e.g. via `f6YD_gyJi`) that assert
the same fact about the same code path, via a different fixture or
file, with no distinguishing edge case between them. Concretely:

1. Group test files by the module/verb they exercise (the claim/ancestry
   cluster named above is one candidate group; there are others — survey
   broadly, don't stop at the first group found).
2. Within each group, read every test function's actual assertions (not
   just names) and classify each pair of similarly-named or
   similarly-shaped tests as: (a) a genuine duplicate — same input shape,
   same code path, same assertion, no distinguishing case; (b) looks
   similar but exercises a real distinct edge case (keep, and if the
   distinguishing case isn't obvious from the test's name, rename it so
   it is); (c) unclear — leave a note rather than guessing.
3. For every genuine duplicate found (category a), remove the redundant
   one and keep the clearer/better-named survivor — never remove a case
   whose edge is even plausibly distinct; a "maybe" is category (c), not
   (a).
4. Report a table: file, test name, classification, action taken (kept /
   removed as duplicate of X / renamed / left as unclear-for-follow-up),
   plus before/after test-function counts and the coverage-stage wall
   time before and after (same `rm -rf o/.coverage` discipline as
   `f6YD_gyJi`'s builder used, to avoid a stale-cache false reading).
