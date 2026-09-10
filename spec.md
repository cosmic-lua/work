## Current refinement — native Cosmic reuse review

This refinement supersedes conflicting implementation assumptions in the historical spec below; its original evidence is retained for context.

The file-cap evidence below is historical: `_work/brief_test.tl` is 438 lines at work a43d1824cd5d48408b780f2ac16a3b42e0c5cd38. Re-measure before resuming; do not keep this item blocked on the former 499-line measurement. Use ordinary automatically discovered `_test.tl` coverage, in the current file when it fits or a cohesive sibling when needed. Test both an unset repo and verbatim explicit repo, after verifying the current intended fallback. Test placement within an obvious low-risk split is an implementation decision, not a question requiring further user approval. Preserve the parent's product contract; do not assume its old unpushed commit is still applicable.

## Question

`«MD7t_OaND»`'s `## Change` asks for a new test in `_work/brief_test.tl` asserting
that `brief` fills `<REPO>` with `product.REPO` when an item's `repo` is unset,
"alongside the existing covered case (an item with `repo` set renders that repo
verbatim)".

## Evidence

Builder `build-MD7t_OaND-6141b568` measured, 2026-09-07, against the item's own
worktree (branch `3Ix3ztns`, off `origin/main`):

- `wc -l _work/brief_test.tl` → 499/500 lines, against this project's hard
  no-exceptions file cap (`bin/cosmic --check lint`). One line of headroom; the
  leanest possible new test in the file's own established style (setup via
  `init_state_repo`/`root_with_leaf`/`give_spec`, one `brief_and_capture` call,
  one assertion) runs 7-8 lines minimum. The code half of the item's `## Change`
  (`_work/brief.tl`, replacing `gh.slug(s, it.repo)` with a `product.REPO`
  default when `it.repo == ""`) is done, gated green, and committed as `fba58ef1`
  on that branch — only the required test cannot fit.
- The spec's premise that `_work/brief_test.tl` already covers "an item with
  `repo` set renders that repo verbatim" does not hold: no such test exists in
  that file. The nearest match, a verbatim-passthrough test for `gh.slug`
  itself, lives in `_work/gh_test.tl`, not `brief_test.tl`.

## What needs deciding

`_work/brief_test.tl` needs headroom before this item's test can land — either
a split (which file gets the new `<REPO>`-fallback coverage, and what else
moves) or folding the new assertion into an existing test in the file rather
than adding a new one. Whichever shape is chosen should also settle where the
repo-set-verbatim case is actually covered (nowhere today, despite the
original spec's claim), since a refined spec should not repeat a coverage
claim that doesn't hold.

## Status of the rest of the item

`_work/brief.tl`'s fix is implemented and gated green (`--check types`, `--check
fmt`, `--check lint`, and the existing `_work/brief_test.tl` suite unchanged at
14/14) in the worktree at `/home/user/wt/3Ix3ztns`, committed locally as
`fba58ef1` on branch `3Ix3ztns`, but NOT pushed — left in place for whoever
resumes this item once the test-placement question is settled.

