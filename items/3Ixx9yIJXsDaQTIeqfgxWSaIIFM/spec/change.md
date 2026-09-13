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
