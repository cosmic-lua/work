## Evidence

`gitboard take ID` for a pull is refused while any diff awaits a verdict the caller could give ("1 diff(s) await a verdict you can give and outrank this take — verdicts before new work"), and the review claim on that diff is itself refused while its CI runs. `_work/gitgate.tl`'s `ci_clears_debt` (:207) already keeps a `running` or `red` head out of the debt — but only from a RECORDED observation: `ciobs.current_state` answers nil for a PR with no `ci_checks` row, and nil "never excludes, the safe default". A PR opened by `take --open` (or handed over by `take --pr N`) has no row until the next `sync` observes it, so in the window between opening and the first sync every pull is refused: work pass 5 hit it three times in one hour (7Vds behind cosmic#1784, ZD1x behind work#73 then cosmic#1785), each with a free agent slot and a ready brief, each waiting 5–25 minutes on a check nobody could claim. The orchestrator ran `sync` at pass start, not between a PR's open and the next pull, and nothing told it to.

## Change

`take --open` and `take --pr N` record the new PR's head in the cache as `running` at handover — the same `ciobs.record` row `sync` would write, with `state = "running"` and the head sha the take just recorded — so `ci_clears_debt` excludes it until an observation replaces the row. `sync`'s own observation then overwrites it as today. `_work/gittake_test.tl`: after `take --pr N` on an item, a pull by another session is accepted (the seeded row reads running); after `ciobs.record` marks that head green, the same pull is refused naming the diff. No change to the refusal text.

## Non-goals

No change to the review claim's own CI gate; no change to `next`'s ordering; no live GitHub call added to `take`.

## Access

cosmic-lua/work, read and write on a branch; no other repository.

## Ready when

Right after `take ID --open`, with no `sync` in between, `gitboard take <a pullable item>` succeeds, and after a `sync` that observes the PR green the same pull is refused.
