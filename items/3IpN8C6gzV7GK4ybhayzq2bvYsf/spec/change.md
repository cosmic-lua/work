In both refusals above, when the claimant matches the minted shape
(`^(build|review|research|refine|decompose)-`), say: "the claim was
minted by an orchestrator — pass `--session <claimant>` to act as it;
`--force --why` only abandons a dead session". Keep the current text
for a session-derived claimant. Both files carry headroom for this
addition inline now — no further split or relocation is needed at
either site.

Tests: `_work/gitverbs_test.tl`'s
`test_a_live_foreign_claim_holds`/drop-refusal coverage for the drop
message, and `_work/gitspec_test.tl`'s
`test_spec_refuses_a_foreign_live_claim` for the spec message — each
needs a case under a minted claimant (e.g. `build-x-1`) and one under
a session-derived/UUID claimant, asserting the two distinct texts.
`_work/gitclaim_test.tl` requires only `_work.gitverbs`/`_work.gitverdict`
and carries neither refusal today — it is not the right home for these
cases.
