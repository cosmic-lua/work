## Current refinement — native Cosmic reuse review

This refinement supersedes conflicting implementation assumptions in the historical spec below; its original evidence is retained for context.

User decision: require applicable non-writing evidence for existing commands; when the item introduces the command itself, accept a failing behavioral reproduction and require preview evidence once implemented. A new command must not be blocked on invoking itself before it exists. Current `--rewrite` without `--apply` follows the find path; it does not validate the replacement or compute apply refusals. `cosmic.ast.rewrite` already computes rewritten text/refusals without writing. Track the CLI preview in board item «oWct_h9xv» (3J7MKAsxNHDmsgHtfRcoWcth9xv) and consume the same rewrite engine rather than hand-rolled shell matching. Refine the bar's evidence vocabulary to accept truthful proposed/refused counts, not an `applied` claim for a dry run. Preserve no-op/refusal readiness policy for existing sweeps; merely mentioning --apply/--fix in prose is not proof that the acceptance is an existing executable sweep.

## Evidence

Item «aAVJ_FXDR» (cosmic#1777) carried an acceptance built from a grep: "`grep -lE '^test_[a-z_0-9]+\(\)\s*$' $(git ls-files '*_test.tl')` → 12 files; run `--rewrite '$F:^test_()' '' --apply` over them, grep → 0". The count was re-verified at pull (12) and the builder still stopped after building the feature: 10 of the 12 are under `testdata/` trees the project model excludes (so `--apply` refuses them by design) and 2 match inside long-string fixtures. The sweep COMMAND was never run at spec time — only its COUNT was. Same pass, two other specs («npTS_YYtP», «qIC7_u6kr») were ended not-planned for Evidence measured on the tree but never checked against the module they targeted. `help bar` (after #68) requires a sweep spec to state the pattern and its `--find` count; it does not require the sweep to have been run once.

## Change

One bar sentence beside #68's: a Change whose acceptance is a sweep (a `--rewrite … --apply`, a `--fix`, any command whose output is the diff) pastes that command's own output from a dry run at spec time — the `applied/refused` line, or the refusal — not only the `--find` count; a paste of `0 applied` or a refusal is a spec that is not ready. The bar check refuses a spec whose `## Change` names `--apply` or `--fix` with no fenced `rewrite:`/`applied` line anywhere in the spec. Tests in the bar's test file: a sweep Change with the pasted line is accepted; without it, refused with a message naming the missing paste.

## Non-goals

No change to `--find`, `--rewrite`, or the #68 sentence.

## Access

cosmic-lua/work, read and write on a branch; no other repository.

## Ready when

`gitboard help bar` prints the sentence, and `take` on a fixture spec naming `--apply` with no pasted `applied` line is refused quoting that.

