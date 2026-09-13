## Change

`brief: review a research handover's board commit instead of refusing
it` (landed as cosmic-lua/work#158) makes `brief review` render a
research review: the "what you're reviewing" section now carries the
`result` commit's findings instead of a product diff. That item confined
its wording change to that one section by its own spec, and chose the
FULL review template outright. So the rest of what a research reviewer
receives is still diff-shaped. Measured 2026-09-13 at `ee3d4f19a`:

```
$ sed -n 131,171p _work/brieftext_review.tl | grep -n 'diff\|Mutation-test\|cosmic --find\|<WORKTREE>'
```

prints "The diff is the Change — everything present, nothing extra", the
`cosmic --find` instruction, and "Mutation-test at least one guard the
change adds … from your own fresh checkout at `<WORKTREE>`". A research
handover has no diff, no guard to mutate, and no product worktree —
`<WORKTREE>` survives unresolved for it — so the reviewer is told to do
three things that cannot be done and must work out for itself which
sentences apply.

Make the rest of the REVIEW template follow the deliverable the way its
"what you're reviewing" section already does: the posture list, the
mutation step and the worktree instruction become a second spliced unit
beside `REVIEWING_DIFF`/`REVIEWING_RESEARCH` — the diff form byte-for-byte
the text that is there today, pinned by `brieftmpl_test`'s rendered
sequence exactly as the first splice is, and a research form that tells
the reviewer what a findings review actually checks: that each measured
claim in the findings names the command that produced it and the command
reproduces against the tree at the commit the findings describe; that
the recommendation follows from the measurements and not past them; that
nothing the spec asked to be measured is missing; and that the
findings are prospective evidence for the item's parent chain, not a
narrative. No mutation step, no `<WORKTREE>`, no `--repo-dir` on the
verdict lines it prints.

The template architecture makes this the same set of files #158
touched: `_work/brieftext_review.tl` (the prose), `_work/briefctx.tl`
and `_work/brieftmpl_source.tl` (the new unit), `_work/briefcontext.tl`
(the splice), the regenerated `_work/brieftmpl/*.tl` — committed, and
`brieftmpl_test.tl` is the drift guard — and `_work/brief_research_test.tl`
for the research rendering, asserting the diff-shaped sentences are
absent from it and the measurement checks present.

## Non-goals

`verdict` accepting a research head. That is «vDqt_wEzX», which this
item sits beside; a research review needs both the right instructions
and a verb that records what it decides, and they are separable.

Any change to the diff-shaped review a product handover receives. The
existing text is the correct review for a diff and stays byte-for-byte;
this item only stops handing it to a reviewer who has no diff.
