## Change

`brief: the review's posture and verdict lines follow the deliverable
too` (cosmic-lua/work#160, accepted) moved the review's posture into a
spliced unit so a research reviewer is no longer told to mutation-test
a board commit. Its fresh-context review read the research render end
to end and found three sentences still diff-shaped, all OUTSIDE the
span that item's spec measured (`sed -n 131,171p`), so it is a spec
boundary rather than a miss. Measured 2026-09-13 at `3607243d3`, in
`_work/brieftext_review.tl`'s shared tail:

```
$ sed -n 272,283p _work/brieftext_review.tl | grep -n 'landed\|mutation-test\|code reviewer'
```

- "after landing, the caller runs `done … --landed SHA`" — a research
  item lands nothing; `done`'s research branch (`gitdone.tl`, as of
  #159) takes `--landed` naming the `result` commit itself.
- the Final report's "the mutation-test you ran and its result" — served
  to a reviewer the posture just told "there is no guard to
  mutation-test".
- the header's "code reviewer … this change" — the same shape.

And one tension the review named in the research posture itself:
step 2 says "re-run that command against the product tree at that
commit — a checkout of your own", while the same brief says there is no
product worktree. Reproduction of a measured claim needs a tree; the
brief has to say how a research reviewer gets one (the item's `repo`
mapped through `repository_map`, checked out at the commit the findings
describe) or the parent chain has to decide reproduction does not need
a checkout. Decide it here and write the sentence; do not leave the
reviewer to reconcile two instructions.

Also `_work/doctrine.tl`'s review page, which #160's builder reported
and left: "Mutation-test at least one guard the change adds…" is stated
unconditionally for every review, and a research review has none. One
clause: the mutation step is the diff review's.

The three sentences become part of the deliverable-following split the
two spliced units already implement — either a third unit for the tail,
or the existing `posture` unit extended to cover it, whichever keeps the
diff form byte-identical (that pin, `DIFF_POSTURE` in `brieftmpl_test`,
must still hold; extend it if the span grows). `brief_research_test`
asserts the three sentences are absent from the research render and the
reproduction sentence names its tree.

## Non-goals

Any change to the diff-shaped review. It stays byte-identical, as #160
guaranteed.

The `spliced_order` in-place claim (#160's review finding 1: the doc
promises tokens "stand where its splice is" and no reachable render can
observe it). Narrowing that doc comment is one line and may ride this
change, but pinning the property needs a fixture that does not exist
and is not owed here.
