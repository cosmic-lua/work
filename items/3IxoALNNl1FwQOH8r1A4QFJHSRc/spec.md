## Evidence

cosmic-lua/work#52 made `take`'s review-debt count skip a diff whose
recorded CI observation is `running` or `red`. Observed 2026-09-06
17:2xZ under the pinned release carrying #52 (2026-09-06-1ff3238): PR
cosmic#1755 was re-pushed (head 5df650c, CI running, recorded with
`take --pr 1755` at 17:2x), then:

    gitboard-take: REFUSED: 1 diff(s) await a verdict you can give and
    outrank this take — verdicts before new work: `take 3IcGmqWF` …

twice, once right after a fresh `sync` ("state is current"). The
`ci_checks` row is keyed by PR, not head: `ci_checks(pr, repo, head, state, observed_at) PRIMARY KEY (repo, pr)`, and
the row for 1755 at 17:26Z read `head=63429b8… state=green` — the
PREVIOUS head, already judged, while the current head 5df650c had CI
running. A row observed on
the previously judged head (green) or no row at all for the new head
counts the diff as debt, so every re-push re-creates the deadlock #52
closed for first pushes.

## Change

`_work/gitgate.tl`'s `ci_clears_debt`: a diff clears the debt count
when the recorded observation is `running` or `red` **for the diff's
current head** — an observation recorded against a different head is
treated as absent. An absent observation for a head that was pushed
within the last 20 minutes (the PR's `head` recorded at `take --pr`
time, `touched_at` on the item) is treated as `running`, since a
push always starts CI and the cache simply has not caught up; older
than that, absent counts as debt as today. `_work/gittake_test.tl`:
a review-state item whose observation is `green` on the OLD head and
whose current head was recorded 5 minutes ago does not block a todo
take; the same with the head recorded an hour ago does.

`sync` (`_work/ciobs.tl` `at_sync`): also observe an item whose head
changed since its last observation, so the cache converges on the
first sync after a re-push.

## Non-goals

No live GitHub call inside `take`.
