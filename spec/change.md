- `_work/dedup.tl` (new, pure): `matches(title: string, items: {Item}, recent_done: {string: boolean}): {Match}`
  where `Match = {id: string, why: string}`. Two tests, either flags:
  1. **title**: lowercase, strip punctuation, drop a fixed stopword
     list, compare token sets; Jaccard ≥ 0.6, or one set contained in
     the other with ≥ 4 tokens.
  2. **subject**: a binding or path token — `unix.<name>`,
     `cosmo.<name>`, `<mod>.<fn>` with a lowercase module prefix, or
     any `[a-z_/]+\.(tl|lua|c)` — present in both titles.
  Candidates: every item with `resolution == ""`, plus every ended
  item whose id prefix appears in `recent_done`.
- `_work/gitgraph.tl` `cmd_new`: build `recent_done` from one call,
  `store.git(s, {"log", "--since=14.days", "--format=%s", "--", "items"})`,
  taking the 8-char prefix after `done `; run `dedup.matches`; on any
  match refuse with `gate.verdict_line("new", false, …)` listing each
  match as `<handle> <why>: <title>`. A new option `--unlike ID`
  (repeatable) names a listed match as not-a-duplicate and lets the
  mint proceed past that one; the acknowledgement is written into the
  new item's spec sidecar as a `## Not a duplicate of` line so the
  reviewer sees it. No `--force`: the doctrine reserves that for repair.
- `_work/dedup_test.tl`: the five pairs above as fixtures (title-only
  hit, subject-only hit, no hit for two unrelated `unix.*` titles);
  `_work/gitgraph_test.tl`: one refused mint, one `--unlike` mint.
- `gitboard help new` and `skills/work/SKILL.md`'s intake paragraph
  name the check in one sentence each.
- The board's own gate passes (`bin/cosmic --make ci` in the worktree).
