## Evidence

Six times this pass the orchestrator built or reworked a diff by hand
— a two-line pin, one docs sentence, two CI-ratchet fixes, a 15-line
sh fix, a test dedupe — at 4-6 calls each against ~40 for a rework
agent (`cosmic _tool/friction.tl` on the pass's transcripts). `help
orchestrate` and `help build` do not say whether an orchestrator may
build, or under which label: `gitboard help orchestrate | grep -c
'by hand'` → 0. The first hand build took its claim under the bare
session id and the next `take` was refused ("one claim per worker" —
40VG_JWAD, 19:07).

## Change

`_work/doctrine.tl`, `orchestrate` topic, one paragraph after the
reconcile bullet: "A change the orchestrator can make in fewer calls
than a builder's brief costs — a pin, one sentence, a ratchet row, a
CI fix under ten lines — it makes by hand: claim under a worker label
(`take ID --session build-<handle>-<sid>`), never the bare session,
build in the verb's worktree, hand over with `--open`, and route the
review exactly as any other diff; the fresh-context review is the
gate, not who typed the diff." `_work/doctrine_test.tl`: the
orchestrate topic contains "by hand".

## Non-goals

No new verb; no change to the one-claim-per-worker rule.
