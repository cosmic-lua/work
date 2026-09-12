## Change

Depends on `item tree: read and write format 5, with declared fields`
(which re-types `result` to a board commit sha) and on `gitboard log
ID` (which can read a commit's message body). Neither this item's
refusal nor its fix makes sense before both.

A research handover cannot be reviewed. `_work/brief.tl` refuses one
outright:

```
$ sed -n 305,317p _work/brief.tl
  -- Every review judges an exact product handover, including research.
  -- Legacy result metadata cannot substitute for or override that commit.
  local head_sha = ""
  if kind == "review" then
    if (it.handover_head or "") == "" then
      if (it.result or "") ~= "" then
        return gate.verdict_line("brief", false,
          ("%s has a legacy research result but no commit handover — the caller must "
            .. "supply the applying product commit with `take %s --head SHA`")
```

That comment is a deliberate stance, not an oversight: it states that
every review judges a product commit, research included. D47 settles the
opposite — the deliverable is a commit in both cases, a product commit
for a diff and a **board** commit for research — so the stance is
superseded and the refusal with it. Reversing a stated intent is the
point of this item, and the record is the authority for doing it.

Today the field is caught between the two: `result` routes the review
CLAIM (`grep -n 'result' _work/gitverbs.tl`) and the `state`/`substate`
views (`_work/indexddl.tl`, both reading `result <> ''`), while the
brief path refuses it. An item can therefore be claimed for review and
then be unable to produce the brief that review reads.

1. `_work/brief.tl`: when `kind == "review"` and `handover_head` is
   empty but `result` is set, produce the brief from `result` instead of
   refusing. `head_sha` becomes the board commit, and the brief carries
   that commit's message body — the findings — as what the reviewer
   judges, alongside the spec it already carries verbatim.
2. `_work/brief.tl`: do not call `local_mechanical_diff` on that path.
   It resolves the product checkout (`repository_map.resolve(s.root,
   it.repo)`) and runs `git diff base head` there, so a board sha would
   make it return false by accident rather than by decision. Select the
   full review template explicitly for a research handover.
3. Rewrite the two-line comment at `:305` to state the rule that now
   holds: a review judges a commit, and which repository that commit
   lives in follows from whether the item's deliverable is a diff or
   board state.
4. `_work/brieftext_review.tl`: the review template's "what you're
   reviewing" section names a product diff. Give the research case its
   own wording — the findings in the handover commit, and the spec they
   answer — without touching the diff case's text.
5. Tests: a review brief for an item with `result` and no
   `handover_head` renders and names the findings; the same item with
   both set still judges the product commit; an item with neither is
   still refused with the unchanged message.

## Non-goals

`take --result` itself, which is unchanged: it records the handover and
this item makes that handover reviewable.

The `state` and `substate` views, and the review-claim routing. Both
already read `result` correctly; the brief path was the only one
refusing it.

`verdict`. Its doc comments claim it refuses a spec that moved since the
handover, which is false today — `grep -n 'verdict_spec\|revision' 
_work/gitverdict.tl` prints one line and it is `it.verdict_spec = ""`.
Correcting those comments is its own change and belongs with whatever
decides whether that refusal should exist.

The 19 items carrying a legacy digest in `result`. The migration carries
them through verbatim; a digest is not a commit, so a review brief for
one still refuses, and re-typing happens on its next handover.
