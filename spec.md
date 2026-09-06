# friction: 2026-09-06 work5-routine

Filed at pass-end with 5 of 6 spawned agents still in flight
(`review-70P4_YBPd-748ecc95`, `build-0oBN_Fa6X-748ecc95`,
`build-LVYj_DA0K-748ecc95`, `build-vmX5_zQH2-748ecc95`,
`research-IOA7_CLf5-748ecc95`) — a bounded pass never waits on a wave
agent. Their sections will be appended to this item's spec as each
reports and its transcript is run through `_tool/friction.tl`, per the
friction doctrine's "none skipped" rule; this is not a second pass, just
this same wave's reconciliation completing asynchronously.

## build 70P4_YBPd

rework round, PR #1744.

numbers: events=50 tool_calls=10 wall=153s tokens in=20/out=536/cache_read=523302/cache_create=65276;
by tool Bash=8/Edit=1/Read=1; errors=0; repeated commands: x2 reading
`docs/guides/lint.md` (re-reading the same file after the edit to confirm
it, not a mistake).

Agent's own account: none. The task was well-scoped — the reviewer's
quoted lines matched the file exactly, the sibling fix in
`quickstart.md` (via `git show`) gave a clear model of intent, and the
`_cli/lint.tl` diff in the same commit spelled out the exact new
behavior needed to write accurate prose. `bin/cosmic --make fetch` and
`--make ci` both succeeded on the first try.

## build 0oBN_Fa6X

Still in flight at pass-end (`build-0oBN_Fa6X-748ecc95`). Not yet
reported — no transcript to run `_tool/friction.tl` against yet. Will
be appended here once it reports.

## build LVYj_DA0K

Still in flight at pass-end (`build-LVYj_DA0K-748ecc95`). Not yet
reported — no transcript to run `_tool/friction.tl` against yet. Will
be appended here once it reports.

## research IOA7_CLf5

Still in flight at pass-end (`research-IOA7_CLf5-748ecc95`). Not yet
reported — no transcript to run `_tool/friction.tl` against yet. Will
be appended here once it reports.

## build vmX5_zQH2

numbers: events=65 tool_calls=14 wall=231s tokens in=30/out=74/cache_read=939659/cache_create=72131;
by tool Bash=7/Grep=2/Read=5; errors=0; repeated commands=0; no edit made
(correctly stopped before touching code).

Agent's own account: verified the spec's file-scope before editing (per
this repo's own "wc -l every file the Change names" rule) and found all
three named files (`_types/gentype_parse.tl` 496/500,
`_types/gentype_render.tl` 489/500, `_types/gentype_test.tl` 499/500)
already within 1-11 lines of the 500-line cap, needing an estimated
25-45 new lines each. Stopped correctly rather than widen scope to a
file split on its own judgment — filed by the orchestrator as child
item `qdDs_EN9Z` for a structural respec (this item is now a container).
The agent's own countermeasure — "the spec's own Evidence section could
have included `wc -l` on the files it names ... which would have caught
this before the item was ever pulled" — is already covered by existing
board item `AY6h_bM0B` ("spec bar: flag a Change-named file already
within ~20 lines of the 500-line cap"); no new item filed for it.

## Orchestrator

- **Goal**: reconcile the previous pass's two `doing` items before filling
  the wave. **What happened**: `0oBN_Fa6X` was `state: building`, claimed by
  a dead prior-pass session (`build-0oBN_Fa6X-fe8c92c8`) with no PR and no
  pushed branch. A bare `drop` was refused (`REFUSED: ... is
  build-0oBN_Fa6X-fe8c92c8's live claim ... abandon a dead session's with
  --force`) even though the claiming session no longer exists in any
  process — cost: 1 extra tool call. **Made the difference**: the tool has
  no way to distinguish "live claim, different session" from "dead session,
  claim never released" other than the caller asserting `--force`; there is
  no lease-expiry surfaced in `show`'s field list to check first.
  **Countermeasure**: `help drop`/`show` could print the claim's age or a
  "stale (no matching live process)" hint so an orchestrator doesn't need to
  hit the refusal once per dead claim to learn it needs `--force`.

- **Goal**: re-claim `70P4_YBPd` (state `rework`, verdict `request changes`,
  PR #1744, original claim `build-70P4_YBPd-fe8c92c8` from a dead prior
  pass) to spawn a rework builder, per `help build`: "`request changes` —
  rework on the same PR". **What happened**: `take 70P4_YBPd --session
  build-70P4_YBPd-748ecc95` (no `--force`) succeeded, but the verb it
  recorded was `review` ("review 3ItZVev6 claimed by build-70P4_YBPd-...")
  and the field `show` prints for the new holder is `reviewer:`, with the
  original `claim: build-70P4_YBPd-fe8c92c8` left untouched; the verdict
  line read "3ItZVev6's review is yours — verdict when done consumes the
  claim". Nothing in `help take`, `help build`, or `help review` documents
  a `reviewer:` field distinct from `claim:`, or says which one a rework
  session should expect to hold, or that the take verb logs a rework claim
  under the `review` verb name. Cost: ~10 minutes and several `show`/`help`
  reads cross-checking whether the claim I held was actually a rework claim
  or an accidental review claim on a PR that had already been reviewed (no
  new commits since the reviewed head, so a fresh review made no sense).
  Proceeded on the strength of `brief builder 70P4_YBPd`'s own verdict line
  ("builder brief for «70P4_YBPd», claim it as build-70P4_YBPd-748ecc95"),
  which agrees with what `take` recorded, as the tie-breaker.
  **Made the difference**: no doctrine text names the `reviewer:` field or
  says a rework claim reuses the review verb/lease. **Countermeasure**:
  `help build` or `help system` should state explicitly that a rework claim
  is recorded the same way a review claim is (same verb, same `reviewer:`
  field, same "consumes the claim" wording) so an orchestrator doesn't have
  to infer it from a brief's verdict line under time pressure.

- **Goal**: claim `LVYj_DA0K` and mint its builder brief. **What happened**:
  `show LVYj_DA0K` had no `repo:` field at all (unlike its sibling
  `0oBN_Fa6X`, which explicitly carries `repo: cosmic-lua/cosmic`), and
  `brief builder LVYj_DA0K` silently defaulted the "Where to work" line to
  `cosmic-lua/work` (the board repo itself) instead of `cosmic-lua/cosmic`
  — the item is entirely about `cosmic/errno.tl`, `cosmic/net/init.tl`, and
  `3p/cosmos/cosmos_pin.tl`, so building against the board repo would have
  been a silent, wrong target. Caught only by reading the brief's "Where to
  work" line closely against the item's actual content before spawning.
  Fixed with `gitboard set LVYj_DA0K --repo cosmic-lua/cosmic`. Cost: ~3
  minutes and 2 extra tool calls; would have been a wasted agent run (build
  against the wrong repo, no PR possible) had it gone unnoticed.
  **Countermeasure**: `brief builder`/`brief research` should refuse (like
  the CI-still-running refusal) when an item has no `repo:` field, rather
  than silently defaulting to the board repo — a missing repo is exactly
  the kind of fact-check the tool already does for other preconditions.
  Filed as board item `3IxHqrApflNsmHz3Uj0eUxZCzX8` (unparented, in triage),
  bundled with the related unpushed-branch finding below.

- **Goal**: reuse "resume from branch X (committed, unpushed)" as written
  in three separate specs (`0oBN_Fa6X` → `Hkal_OAFy`'s branch `3Iw35aAO`;
  `LVYj_DA0K`'s own branch `3Iw4Klc9`; `IOA7_CLf5`'s draft-patch branch
  `3IpBKtB8`). **What happened**: all three branches are gone —
  `git ls-remote origin 'refs/heads/<branch>*'` returns nothing for each,
  because each was committed inside a PRIOR session's ephemeral remote
  container (this project runs orchestrator sessions as fresh, disposable
  cloud containers, not a persistent developer machine) and never pushed;
  the container was reclaimed before this pass started. `help build`'s own
  stop-short instruction ("Leave your diff committed on the item branch
  (unpushed), never reverted: the respec starts from it") is exactly what
  produced this — sound advice on a persistent machine, silently fatal
  here. Cost: 3 × one `git ls-remote` round-trip to discover each was gone,
  plus rewriting each affected brief's bounce-context to instruct the
  spawned agent to re-derive the referenced work from the spec's Evidence
  prose instead of resuming a branch, and (for the two new builders) to
  push their branch even on a stop-short instead of leaving it local-only.
  No item outright failed, but the "resume, don't restart" time savings
  the specs promised could not be honored, ~10-15 minutes of orchestrator
  time reconstructing intent from prose across three items.
  **Countermeasure**: filed as board item `3IxHqrApflNsmHz3Uj0eUxZCzX8`
  — `help build`'s stop-short guidance should tell a builder to PUSH its
  WIP branch (no PR needed) rather than leave it local-only, since this
  project's actual environment cannot guarantee a local commit survives to
  the next session.

- No other friction: `sync`, `show`, `next`, and the review-comment lookup
  for the bounce context (`pull_request_read get_comments` on #1744, since
  `get_reviews` returned empty — the verdict was posted as a PR issue
  comment, not a submitted GitHub review) all worked as documented on
  first try.
