# Historical snapshot-publication implementation evidence

This record preserves the PR #173 implementation process and validation runs.
It is evidence for the source revisions named below, not the current design or
a promise that every old harness remains runnable. The JavaScript Work adapter
described in the record was retired after owner review; Work sessions now
perform the Teal-emitted protocol calls directly.

## Delivery

Implement and review the core, then CLI/composition integration, then the
Work integration and final compatibility checks. Use one Sol implementation
subagent at a time. Run the repository gate and an independent adversarial
review, and submit a draft PR. Deployment, migration, pin changes and merge
are separate work.

## Implementation evidence

Stage 1 (`92a103a4d`) adds the snapshot identity, connector protocol and
recovery core. Its eight focused test functions passed, as did scoped
formatting, strict type checking and lint for all five new files.

An independent detached checkout tested five semantic mutations: bypass the
whole-head check, ignore the lease deadline, accept a different returned
tree, ignore the receipt tree, and ignore the receipt message. All five
were caught by assertion failures in the focused suites; direct source
execution of the restored suites passed. This verifies the guards are
exercised, beyond merely obtaining a green unmodified run.

Stage 2 (`82e99df14`) integrates ordinary composition, final-board validation,
shell publication, restart recovery and the JSON protocol. Its 32 focused
tests passed; all 316 Teal modules compiled, and scoped formatting and lint
passed. The prerequisite follow-up (`43fdcf198`) updates the shared caller
fixture, refresh bookkeeping, repository mappings and recovery planning.

The real Work connector exercise used the isolated branch
`validation/gitboard-snapshot-20260914`, with Teal at `43fdcf198` and the
Work runner and callback example under development on this PR:

- Creating an item and spec, editing and reverting its title, then setting
  a summary produced one final commit over the original canonical parent.
  Local `230cef58b8b9fa8a104050bbcf6efae09c822713` published as provider
  commit `dd644c558dfcb40d624397062cface1870339014` in exactly three writes.
- A second update published local
  `617dc9120e03406d22669ec0de08b03886d83c44` as provider commit
  `47f6c7fa597cbca2c6af4f97777220e4c53bffa0`. After the actual branch update,
  the test injected a lost response and a failed fetch. Restart confirmed
  that saved candidate with zero additional connector writes.
- Independent guards checked the candidate/recovery files before each ref
  update and restricted all writes to the isolated branch. Both confirmed
  results reported only the affected item and empty spec-issue arrays.

The Work bridge at `df37e777d` also transferred a 36,000-byte JSON payload
containing 12,000 CJK characters through the actual Work execution tools.
The recovered string matched exactly, and cleanup of its owned temporary
file and directory succeeded. This local transfer proof made no connector
writes and covers the large-response path beyond the inline publication
exercise above.

The retained-suite repairs and final-state authority checks at `231f8cc59`
passed the complete repository gate: 1,058 tests across 159 files, format,
strict type checking, lint, and 84.4% coverage. GitHub CI also passed for
the identical published tree. No coverage floors were lowered.

The final concurrency/recovery implementation at `12ab3c723` passed its
31 focused Teal tests and all 14 Node tests. Its standalone build passed
for 350 files and one binary. A new real Work exercise used that exact
standalone binary and committed JavaScript sources on the same isolated
branch:

- Local commit `60802b82fb5b817b79e807021fa6baf8c3719665` published as
  `86a8030652d0fdd8e45df53aaa4b66e7d1db8ced` in exactly three connector
  writes. The returned tree matched the local tree, and an independent
  check proved the candidate was durably saved before the ref update.
- The test discarded the final confirming CLI response after successful
  cleanup. Work returned `uncertain`; the snapshot ref and all temporary
  recovery records were absent.
- Restarting the same local commit with every connector mutation blocked
  returned `confirmed` for that exact provider commit, using zero extra
  writes. Cleanup again left no proposal or recovery record.
