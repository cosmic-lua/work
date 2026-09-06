## Evidence

The review brief tells a reviewer CI is mechanical
(`_work/brieftext_review.tl:52` "CI is mechanical, but read it fresh
on the PR's CURRENT head") and to mutation-test "from your own fresh
checkout" (`:70-73`), but never says what NOT to run. Measured on
this pass's transcripts (`cosmic _tool/friction.tl <task .output>`):
the PR 1759 round-2 reviewer (25 calls) spent 8 of them running the
full `bin/cosmic --make ci` in its fresh worktree after reading five
green check runs on the same head — "ci: PASS (5 stages), 3373 tests"
repeated in its report; the round-1 reviewer (40 calls) and the PR 59
reviewer (36 calls) did the same. A full cosmic gate is ~4 minutes and
~6 calls per review that CI already spent on the identical commit.

`git grep -n 'make ci' -- _work/brieftext_review.tl` → no hit: the
template is silent, so each reviewer decides alone, and three of three
decided to re-run it.

## Change

`_work/brieftext_review.tl`, the `REVIEW` template only:

- step 1 (`:52-54`) grows one sentence after "stop and report why.":
  "Green means the gate ran on this exact head — never re-run
  `--make ci` or the full test stage yourself; the checks you run are
  the ones the diff's own test file and your mutation need."
- the mutation paragraph (`:70-73`) names the shape: "run the ONE test
  file that guards it (`bin/cosmic --make test <file>` in cosmic,
  `bin/cosmic --make test _work/<file>` in work), not the suite".

`_work/brieftext_test.tl`: one assertion per new sentence, the same
`find(..., 1, true)` shape the file already uses for the templates.
`RESEARCH_REVIEW` and every other template are untouched.

## Non-goals

No change to what CI red or running means (step 1's stop rule stays),
no change to the builder brief's own "full gate once before the push"
(a builder's gate is the first run on that head; the reviewer's would
be the second).
