Handing one item to a fresh-context reviewer costs twelve gitboard invocations,
three refusals, and two board publishes before the reviewing agent can start.
Measured in one session, handing two items to two reviewers:

    brief review dOmj_JNWN --session $BUILDER
    gitboard-brief: --session requires a builder --receipt
    brief review dOmj_JNWN
    gitboard-brief: 3JEKGntl is still claimed by the session that built it — REFUSED: 69a0b7ce… built/specced 3JEKGntl — the verdict needs a fresh context; recording it anyway needs --force --why
    help brief
    drop dOmj_JNWN BK2V_8tI0 --session $BUILDER --execute
    session new
    claim dOmj_JNWN BK2V_8tI0 --session $REVIEWER --fetch-base
    publish 636571b0…
    refresh --execute
    brief review dOmj_JNWN --out … --gitboard-command … --gitboard-cwd …
    brief review BK2V_8tI0 --out …
    gitboard-brief: … fill <WORKTREE>
    worktree BK2V_8tI0 --session $REVIEWER
    gitboard-worktree: preparation failed: no verified runtime for sha256 dd6b44b0…; use --fetch for explicit acquisition
    worktree BK2V_8tI0 --session $REVIEWER --adopt … --fetch --receipt-out …
    brief review BK2V_8tI0 --out … --tree …

Two costs land after the agents run, too. A reviewer PREPARES its verdict and
leaves the publish to the caller, so a caller that spawns reviewers and stops
watching leaves verdicts invisible on the board — in the measured session both
verdicts sat unpublished until the orchestrator noticed. And a pending
composition is owned by ONE session, so while a reviewer's verdict is
uncommitted the orchestrator cannot compose anything at all:

    new "…" --repo cosmic-lua/work --spec-file …
    gitboard-new: snapshot composition belongs to 5f7f5b412cbe21fc7791b0eb7d558c38; pass the same --session or set GITBOARD_SESSION

Two concurrent reviewers therefore serialize through one composition slot, and
the orchestrator is locked out of its own board until it publishes on their
behalf.

Every step exists for a reason and none of it is what the caller wanted, which
was a brief to hand an agent. The doctrine's actual requirement is one sentence
(`gitboard help review`): "a subagent whose context window never held the
build". The claim machinery is how that is currently enforced, and the caller
performs it by hand.

Add `gitboard review ID...`, one verb that produces reviewer-ready briefs:

1. `_work/stateclaim.tl` — add `"handoff"` to the `Action` enum
   (`grep -n "local enum Action" _work/stateclaim.tl`, today `"take"`,
   `"renew"`, `"drop"`). `prepare` takes ONE action for a whole request set
   (`grep -n "local function prepare(root: string, head: string, requests: {Request}, action: Action," _work/stateclaim.tl`),
   so drop-then-take cannot be one commit and a transfer primitive is what
   makes the single publish possible. `handoff` writes the new holder's claim
   blob over the existing one for an item whose state is `review`, refusing
   when the state is anything else, when the requesting session is absent from
   the item's builders/speccers check in the opposite direction (the new holder
   MUST NOT be a builder or speccer), or when no claim is currently held.
   The product base and work branch are preserved from the claim being
   replaced: the reviewer judges the same handed-over commit, so a fresh base
   would be wrong.
2. `_work/gitcommands.tl` — declare the verb beside the other entries, with
   `--out FILE` (repeatable per id, or a directory), `--session`,
   `--tree`, `--gitboard-command` and `--gitboard-cwd` carried through to
   `brief`, and `--fetch` carried through to `worktree`.
3. `_work/gitboard.tl` — the argv dispatch branch.
4. `_work/gitverbs.tl` — the `cmd_review` entry, which composes what a caller
   does by hand today, in order: mint a reviewer identity when `--session` is
   absent (the same mint `session new` performs), prepare ONE `handoff` batch
   over every named id, print its publication command, and after the caller
   publishes and refreshes, create each item's worktree when its brief needs
   one and write each filled brief to `--out`.

The verb PREPARES, like every other mutating verb — it does not publish. Its
verdict line names the one publish command for the whole batch, so two items
cost one publish instead of two.

Line budgets (`wc -l`): `_work/stateclaim.tl` 158 and `_work/gitcommands.tl`
451 have room. `_work/gitverbs.tl` is 379 of the 500-line cap and
`_work/gitboard.tl` 488, so `gitboard.tl` gets only its dispatch line and
`cmd_review`'s body goes in `gitverbs.tl` if it fits in ~120 lines, otherwise
in a new `_work/gitreview.tl` that `gitverbs` calls. Measure after formatting,
not before the fmt stage runs.

Regression: `_work/stateclaim_handoff_test.tl` pins the new action — a handoff
to a non-builder session on a `review` item replaces the holder while
preserving `product_base` and the branch; a handoff to a builder/speccer
session refuses; a handoff on a `building` or `todo` item refuses; a handoff
with no live claim refuses. Then extend `_work/gitverbs_test.tl` (or add
`_work/gitverbs_review_test.tl` if that file is near the cap) with the verb's
composition: one prepared commit for two ids, and a refusal that names the item
rather than the batch when one of them is not in `review`.

`_work/stateclaim.tl` has no `.cosmic-coverage` row (`grep -n "stateclaim"
.cosmic-coverage` returns nothing against 91 rows, `grep -c '\["_'
.cosmic-coverage`), so none moves; a new test file may add one, measured with
`bin/cosmic --make coverage`, that row alone, carrying its measured basis.
