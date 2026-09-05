# friction: 2026-09-05 work9-routine (/work 9 --routine)

## orchestrator

- **Goal:** spawn the first builder agent (A3HK_gamw) with the brief `gitboard
  brief builder` emitted.
  **Actually happened:** passed the literal shell fragment
  `$(cat /tmp/.../brief_A3HK_gamw.txt)` as the Agent tool's `prompt` string
  instead of the file's actual text — the Agent tool takes a plain string,
  never shell-expanded — so the agent launched with a useless four-word
  prompt. Caught immediately on the next turn (no tool output was consulted
  first), cost one `TaskStop` call and a full prompt re-composition; no
  tokens burned inside the misfired agent beyond its launch.
  **Contributed:** habit of writing brief-passing as a shell one-liner
  transferred into a tool call that does not evaluate shell syntax.
  **Improvement:** always `Read` the brief file's actual content (or keep it
  already in context from generating it) and paste that text into `prompt`
  literally; never write `$(...)` into a tool-call string. Doc/skill-level
  only — not a gate a tool can enforce.

- **Goal:** pull «jiP8_yJF8» (`cosmic.ksuid`) as a normal builder item and
  spawn its brief.
  **Actually happened:** `gitboard brief builder jiP8_yJF8` emitted a brief
  targeting `cosmic-lua/work` as the PR repo ("You are a builder agent for
  `cosmic-lua/work`" / "Open a PR ... in `cosmic-lua/work`"), but the spec's
  own `## Change` names `cosmic/ksuid.tl`, `cosmic/ksuid_test.tl`,
  `cosmic/ksuid_example.tl`, `cosmic --docs`, `cosmic --examples` — all
  cosmic-lua/cosmic paths. `ls cosmic-lua/work`'s checkout confirms there is
  no `cosmic/` tree there at all. Caught by reading the brief closely before
  spawning; cost one extra `show`/`ls` round, a `gitboard set --repo
  cosmic-lua/cosmic`, and a brief regeneration — cheap here, but a spawned
  agent that had NOT caught this would have opened a PR against the wrong
  repository entirely, an unwind only a human notices.
  **Contributed:** `gitboard new`'s `--repo` defaults silently to the
  board's own origin when unset (`_work/gh.tl:45`'s `slug`, read from
  `git remote get-url origin`, consumed by `_work/brief.tl:301`) — confirmed
  by reading `_work/itemtree.tl` (no parent-repo inheritance exists at the
  storage layer at all; `repo` is per-item, `""` when unset) and `_work/gh.tl`
  (the empty-string fallback to the checkout's own origin). `jiP8_yJF8` was
  evidently filed with no explicit `--repo`, so it silently inherited
  cosmic-lua/work by virtue of being filed from that checkout, with nothing
  in `show`'s output flagging the mismatch against its own spec content.
  **Improvement:** a gate in the tool would beat a doc here: `gitboard new`/
  `set`/`spec` could grep the spec body for a path shape unambiguous to one
  repo (e.g. a `cosmic/*.tl` module path when `--repo` defaults to
  cosmic-lua/work, which carries no `cosmic/` tree) and refuse or warn
  rather than file silently. Left as a candidate below — the exact
  detection rule needs a refiner's judgment, not mine to spec unilaterally
  mid-pass.

- **Goal:** pull «va0I_6MWO» (whole-board dedup sweep) as a normal builder
  item.
  **Actually happened:** its own spec step 2 says it "reuse[s] «XSDr_DioY»'s
  combined-query shape ... once it lands" — but `gitboard show XSDr_DioY`
  showed `state: todo`, unblocked, unbuilt. The item still passed the spec
  bar and `next` offered it as the top pull, because the forward dependency
  lives only in the spec's prose, not as a graph edge. Caught by reading the
  referenced item before spawning (`show XSDr_DioY`); cost one extra `show`
  read plus a `gitboard block va0I_6MWO XSDr_DioY --reason ...` call,
  instead of a spawned agent discovering the same gap fresh and bouncing
  (per `help build`'s own "bounce is a good outcome" step) — one Bash+one
  Read here vs. a full agent spin-up, bootstrap, and STOP report there.
  **Contributed:** the refiner who wrote va0I_6MWO's spec named the
  dependency in imperative prose ("once it lands", referencing another
  item's id) without also recording it as a `block` edge at spec time.
  **Improvement:** doc-level fix in `skills/work/decompose.md` or `gitboard
  help bar`: a spec sentence that names another open item's id as a
  precondition should become a `block` at refine time, not prose alone.
  Left as a candidate below.

- **Goal:** claim the review already awaiting a verdict on «U7bX_uuKQ» (PR
  #37), per orchestrate step 3 (reviews outrank pulls).
  **Actually happened:** `gitboard take U7bX_uuKQ --session
  review-U7bX_uuKQ-4597e9df` refused: `REFUSED: 3ItLbVKX is under review by
  review-U7bX_uuKQ-32638265 — take over a live review with --force --why`.
  A second, concurrently-running orchestrator session (`32638265`) had
  already claimed the same review roughly seven minutes earlier. No
  `--force`d: left it per "a lost race is the lock working." Zero cost
  beyond the one refused call — correctly not spawning a duplicate reviewer.
  **Contributed:** two orchestrator sessions running the standing loop
  against the same board concurrently (this is by design — "N orchestrator
  sessions" is explicitly supported), so the doing lanes and claim locks are
  the only thing preventing duplicate work, and here they worked exactly as
  documented.
  **Improvement:** none — this is the mechanism working as intended, not a
  gap.

- **Goal:** close out «A3HK_gamw» once its builder reported the item's
  outcome was already satisfied by an unrelated already-merged PR (#1705),
  with no diff of its own to land.
  **Actually happened:** `gitboard done A3HK_gamw --reason completed`
  refused: `REFUSED: 3Io95oBM has no PR and no accept — an evidence-only
  item takes a verdict too; record one (\`gitboard verdict\`), or end it
  without review via --force --why`. Re-ran with `--force --why <the
  builder's verification chain, quoted>` and it recorded cleanly. Cost one
  refused call plus composing a precise `--why`.
  **Contributed:** the refusal message names the exact bypass and the
  reasoning it wants, so the second call succeeded first try — the tool
  steered correctly here, this is not a gap.
  **Improvement:** none.

- **Goal:** record the merge of «U7bX_uuKQ» (PR #37) once GitHub showed it
  `merged: true`.
  **Actually happened:** `gitboard done U7bX_uuKQ` (no flags) failed: `lost
  the push race — the mutation was dropped whole and the checkout re-synced;
  re-run the verb against the current board`. Re-ran the identical command
  once more; it reported `nothing to record: done 3ItLbVKX completed (from
  accepted) leaves the board unchanged` — the concurrent session (`32638265`)
  had already recorded the same `done` in the race window. Cost: two calls
  where one sufficed, but the tool's own re-sync-and-report-noop path made
  the redundancy free rather than a conflict.
  **Contributed:** the same concurrent-session situation as the review-claim
  entry above.
  **Improvement:** none — again the mechanism (push race → resync → retry)
  worked exactly as its own error message says to use it.

- **Goal:** merge the accepted PR #37 directly, believing the review agent's
  `accept` verdict might not yet have triggered a merge.
  **Actually happened:** `mcp__github__merge_pull_request` returned `405
  Pull Request is in the merge queue.` — the review agent (or GitHub's own
  branch-protection auto-merge) had already queued it; my direct-merge
  attempt was redundant but harmless (GitHub refused it cleanly rather than
  double-merging). No cost beyond the one API call.
  **Contributed:** the review brief's own instructions say the reviewer
  enables auto-merge on accept, which is what had already happened; I
  didn't need to check `auto_merge`/merge-queue state before attempting a
  direct merge.
  **Improvement:** minor process note for future passes: check the PR's
  merge-queue/auto-merge state before calling merge directly, to avoid one
  guaranteed-redundant call. Not worth a tool change.

## build A3HK_gamw (Sonnet 5) — stopped short (target already merged elsewhere), 275s, 13 tool calls, tokens in=28 out=41 cache_read=743262 cache_create=43951

- **Goal (agent's own report):** confirm the spec's premise (the
  3p/cosmos pin lag and its listed unadapted call sites) before making any
  edit.
  **Actually happened:** the very first re-measurement (`cat
  3p/cosmos/cosmos_pin.tl`) showed the pin already past the spec's stated
  target; a from-scratch cold `bin/cosmic --make fetch && --make ci` (~10
  of the stretch's ~4.5 minutes) confirmed `ci: PASS` with zero edits
  needed, and `git merge-base --is-ancestor` confirmed the fix had already
  landed via an unrelated PR (#1705).
  **Contributed:** the item's spec was refined against a snapshot of `main`
  that had already moved by the time this attempt pulled it — an inherent
  risk of a long-lived spec, not a brief or tooling defect; the agent's own
  report says the "re-verify against current tree" instruction is exactly
  what caught it.
  **Improvement:** none identified by the agent; this is the queue-aging
  risk `help build` already documents ("the queue ages faster than the tree
  stands still").
- **Goal:** understand why a commit whose own message said "NOT mergeable
  yet: a genuine cold-build gap" was in fact merged to `main`.
  **Actually happened:** a few extra `git log`/`merge-base` commands to
  confirm the gap was closed by an immediately-preceding commit rather than
  still live; concluded the merged message was stale WIP text surviving a
  squash-merge, not a live defect.
  **Contributed:** no doc or code gap — a stale commit message, not
  reproducible, not worth filing per the agent's own account.
  **Improvement:** none.

## build jiP8_yJF8 (Sonnet 5) — still running

Claimed and spawned this pass; not yet reported. Its friction section is
written when it reports, in a later pass's log per
`skills/work/friction.md`'s "what the agent reports".

## research Ng6q_dpp2 (Sonnet 5) — still running

Claimed and spawned this pass; not yet reported. Its friction section is
written when it reports, in a later pass's log.

## build TiP5_t8cl (Sonnet 5) — still running

Claimed and spawned this pass; not yet reported. Its friction section is
written when it reports, in a later pass's log.

## candidates

- «jiP8_yJF8»-shape repo mis-defaulting: `gitboard new`/`set`/`spec` filing
  an item whose spec content is unambiguous to one repo (a `cosmic/*.tl`
  module path, `cosmic --docs`/`--examples`) while `--repo` defaults
  silently to the board's own origin (`_work/gh.tl:45`, `_work/brief.tl:301`)
  — stays here for triage: the exact detection/refusal rule (a path-shape
  grep? a refiner-time prompt? a `show`-time warning alongside its existing
  `graph:`/`bar:` problem lines?) is a design choice for whoever refines it,
  not mine to spec unilaterally mid-pass.
- Forward dependencies named only in spec prose (va0I_6MWO → XSDr_DioY)
  should become `block` edges at refine time — stays here for triage: a
  doctrine-sentence fix (`skills/work/decompose.md` or `gitboard help bar`),
  not a code gate; the exact wording is a refiner call.
