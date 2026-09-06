## Evidence

`_work/brief.tl:203-217`'s `bounce_context()` exists specifically so a
rework brief's `<BOUNCE_CONTEXT>` auto-fills with the reviewer's
finding, sparing the orchestrator from hand-assembling it:

```
local function bounce_context(s: store.Store, it: item.Item): string
  if (it.verdict or "") ~= "request changes" or (it.pr or 0) == 0 then
    return ""
  end
  local revs, _err = gh.reviews(s, it.pr, it.repo)
  if revs == nil then
    return ""
  end
  local finding = gh.latest_request_changes(revs)
  if finding == nil then
    return ""
  end
  return fill(brieftext.REWORK,
    {REVIEWER_FINDING = finding.body, BRANCH = it.id:sub(1, 8)})
end
```

`gh.latest_request_changes` (`_work/gh.tl:263-`) only matches a formal
GitHub PR REVIEW object whose `state` is `"CHANGES_REQUESTED"` (the
`gh.reviews` read, documented at `_work/gh.tl:208-210`, enumerates
`"APPROVED" | "CHANGES_REQUESTED" | "COMMENTED" | "DISMISSED" |
"PENDING"`).

The review brief's own instructions for that verdict
(`_work/brieftext_review.tl`, "Recording your verdict" section) say:

    - request-changes: post the concrete gaps, quoted with file:line, as
      a PR comment. Do not push a fix yourself — the builder reworks on
      the same PR.

"a PR comment" is a plain issue comment (`add_issue_comment` in the
GitHub MCP surface a review agent actually has), not a formal PR
review. Reproduced directly, 2026-09-06: a review agent given exactly
this brief for board item `hnlE_A39n` (PR `cosmic-lua/cosmic#1742`)
recorded `request changes` via `gitboard verdict` and posted its
findings via a plain issue comment
(`https://github.com/cosmic-lua/cosmic/pull/1742#issuecomment-5556615465`).
The very next `gitboard brief builder hnlE_A39n` (a rework brief)
still rendered a literal, unfilled `<BOUNCE_CONTEXT>` placeholder —
`bounce_context()` found no formal review, only a comment, and
returned `""`. The orchestrator had to fetch the comment and hand-fill
the `REWORK` template manually to brief the rework agent.

This is not a one-off: EVERY future request-changes verdict recorded
by an agent following the review brief's current instructions hits
this same gap, since the instructions and the lookup were never wired
to agree.

## Change

`_work/brieftext_review.tl`'s "Recording your verdict" section,
`request-changes` bullet: change the instruction from posting a plain
PR comment to posting a formal GitHub PR review in the
`CHANGES_REQUESTED` state, using the GitHub MCP server's own documented
workflow (its tool instructions: "Always use `pull_request_review_write`
with method 'create' to create a pending review, then
`add_comment_to_pending_review`... and finally `pull_request_review_write`
with method 'submit_pending'") — for a single overall-findings body (no
per-line comments needed here), `pull_request_review_write` with
method `create` and an `event`/`state` of `REQUEST_CHANGES` and the
findings as the review `body` in one call should suffice; verify the
exact parameter shape against the tool's current schema when
implementing, since this file describes the write pattern, not the
exact call signature.

Keep the existing guidance to quote gaps with file:line and to not
push a fix — only the delivery mechanism (formal review vs. plain
comment) changes.

`_work/brief_test.tl` or `_work/brief_rework_test.tl` (check current
headroom — see the sibling item on `product_root()` for both files'
line counts as of 2026-09-06, prefer whichever has room): add a test
that a rendered review brief's request-changes instructions name
`pull_request_review_write` (or the review-object-creating call) and
do not say "PR comment" for this bullet.

## Non-goals

- Not changing `bounce_context()` itself, or `gh.reviews`/
  `gh.latest_request_changes` — the lookup is correct for what a
  formal GitHub review actually is; the mismatch is on the
  instruction side.
- Not changing the `accept` or `reject` verdict instructions, which
  don't rely on `bounce_context` the same way.
- Not touching how `gitboard verdict` itself records board state —
  this item is only about what the review AGENT posts to GitHub.
