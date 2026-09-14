# Response to the format-6 implementation reviews

The two reviews on PR #171 inspected `0e3701fd9`. This follow-up keeps the
implementation in draft and addresses the findings against the merged storage
design. The review is not an approval of release, production activation, or
the consumer pin change.

## Decisions

The broken tests, duplicate startup reads, full-board claim gates, ambient Git
trailer configuration, missing take bound, incomplete losing-attempt cleanup,
shared migration history, and trailer text presented as notes are correctness
or regression bugs. They require code fixes and independent regression tests.

Two findings require an explicit design amendment, included in
`docs/design/storage.md` for review:

- The ChatGPT Work commit tool chooses the physical Git author. Both executors
  preserve the session's logical author in the canonical `Gitboard-Author`
  literal trailer, which confirmation checks. This is writer-supplied
  provenance, not authentication of the session.
- Trailer-only legacy events must retain item attribution and exact tip/mark
  relationships. Their materialized attribution paths carry empty content;
  readers omit empty bodies from displayed notes. Dropping those events would
  lose the history semantics the migration is intended to preserve.

The connector vocabulary is specific to ChatGPT Work. A connector exposing
only `push_files` cannot publish a multi-transition draft atomically with the
current adapter. Publishing each transition separately is not a compatible
substitute.

The later fresh-context review corrected narrow membership races that path-only
fences could miss. Rank now fences its target item; attach checks and fences old
and new parent authority even if neither parent blob changes; completing an
outcome rechecks the absence of open children; take rechecks its full readiness
predicate and canonical doing count; and depend rechecks both endpoints. The
regressions cover both publication orders for rank/attach, done/attach,
take/attach, and depend/done, plus sequential foreign claimed-parent refusal.

The draft-prefix review keeps every saved publication snapshot immutable. When
an exact ordered prefix becomes canonical while the source draft advances,
refresh may CAS-rewrite only the live draft receipt to its rebased remaining
suffix. Non-exact chains conflict; truncated or unknown searches stay pending.

## Scope and remaining review

This integrated implementation is associated with container
`3JHjIHZci3VOBQhQVBOyDA5DbKm` (`«yDA5_DbKm»`), covering code and validation
components of steps 1–9. The board's child handovers and acceptances still need
to be recorded through its review flow. Neither the PR nor the review closes
those items. Normal per-item, claim-batch, `board/seq`, and pack transports are
retired by this PR; only `migrate6` retains their decoding and Git plumbing.
Release the native-only binary, run that binary's migration, obtain separate
production activation approval, activate, then update the consumer pin.

The validation reports distinguish actual connector execution, an isolated
full-board replay, synthetic publication/freeze tests, and mutation evidence.
A test provider cannot establish that a production ruleset is active. No live
board ref, freeze ruleset, or consumer pin was changed by this follow-up.

**Current integrated gate: pending.** Final test and six-catalog mutation totals
belong to the final merged checkout and are not inferred from these historical
review runs.
