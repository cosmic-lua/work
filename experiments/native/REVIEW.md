# Response to the format-6 implementation reviews

The two reviews on PR #171 inspected `0e3701fd9`. This follow-up keeps the
implementation in draft and addresses the findings against the merged storage
design. The review is not an approval of the live cutover.

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

## Scope and remaining review

This integrated implementation is associated with container
`3JHjIHZci3VOBQhQVBOyDA5DbKm` (`«yDA5_DbKm»`), covering code and validation
components of steps 1–9. The board's child handovers and acceptances still need
to be recorded through its review flow. Neither the PR nor the review closes
those items. Release/pinning, the production freeze and cutover, and retirement
remain separate steps 10–12.

The validation reports distinguish actual connector execution, an isolated
full-board replay, synthetic publication/freeze tests, and mutation evidence.
A test provider cannot establish that a production ruleset is active. No live
board ref, freeze ruleset, or consumer pin was changed by this follow-up.
