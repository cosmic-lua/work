One read, added to `_work/gitverdict.tl`'s `cmd_verdict`, and the two
branches it enables. `wc -l < _work/gitverdict.tl` is 152.

1. **Read the PR on an accept.** After the existing builder-distance
   refusal and before the item is mutated: when `kind == "accept"`,
   the item names a PR (`(it.pr or 0) ~= 0`) and the board has an
   origin (`store.has_origin(s)`, the same guard
   `gate.handover_refusal` uses), call `gh.pull(s, it.pr, it.repo)`.
   A read that FAILS is not a refusal — fall through to today's
   behaviour, so a network outage cannot wedge reviews.

2. **Closed and unmerged is refused.** The decision is a PURE
   classifier, `review.blocks_accept(p: Pull): string`, added beside
   `blocks_check` and `blocks_on_ci` in `_work/review.tl` and shaped
   exactly like them — the refusal an accept earns, nil when none. It
   returns
   `PR #<n> is <state> and unmerged — there is nothing to land; reopen it, or reject the item`
   when `p.state ~= "open" and not p.merged`. `cmd_verdict` prefixes
   `REFUSED: ` and the item does not move. Pure, because that is how
   this repo tests GitHub-shaped logic: `gh_test.tl` exercises
   `is_merged`/`refusal` over literal values and leaves the transport
   to the real land flow.

3. **Merged completes the item in one commit.** Set `verdict`,
   `verdict_head`, and `pr` exactly as the accept path does today,
   then instead of `phase = "land"` set `phase = ""` and `resolution
   = "completed"`, and pass `gate.rephased_parent(it, all)` as the
   `also` argument to `commit_and_publish` — a container whose last
   open child just ended must return to `plan`, which is what
   `cmd_done` does and what this path would otherwise skip. Commit
   subject:
   `verdict <id8> accept (check -> completed) by <session>, merged <sha7>`,
   with the ` by <session>` half omitted when no session is named,
   exactly as the existing subject does. `<sha7>` is the merge commit,
   so the log records which merge completed the item without a new
   field on `Item`.
   Verdict line: `accept on <id8>: check -> completed (PR #<n> was
   already merged)`.

4. **`review.Pull` gains `merge_sha: string`**, parsed in
   `_work/gh.tl`'s `pull` from `merge_commit_sha` the way `head_sha`
   is parsed from `head.sha`, `""` when absent. `wc -l < _work/gh.tl`
   is 204 and `wc -l < _work/review.tl` is 96.

5. **Tests.** `_work/review_test.tl` (82 lines) gains
   `test_blocks_accept_refuses_a_closed_unmerged_pr`, covering all
   four combinations of `state`/`merged` over literal `Pull` values —
   open-unmerged and merged (both nil), closed-unmerged and
   closed-merged (refusal, and nil, since a merged PR reads as
   closed). `_work/gitverdict_test.tl` (135 lines) gains
   `test_accept_without_an_origin_still_routes_to_land`, which pins
   the `store.has_origin` fallthrough that keeps every existing
   verdict test — all of which run on local-only boards — meaning what
   it meant before.

   The transport half (`gh.pull` returning a merged PR, and the
   one-commit completion it triggers) is NOT unit-tested, for the same
   reason `gh.merge` is not: it needs a real repo and token. It is
   exercised the first time a session accepts an already-merged PR,
   and items `3IE6ttNh` and `3ICDOGbm` are both sitting in `check`
   with merged PRs, so that happens on the next verdict either of
   them gets.
