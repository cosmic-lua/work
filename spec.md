# Intent

Make gitboard coordinate work entirely through Git data while leaving every
authenticated or remote interaction to the caller.

# Acceptance

- Remote boards treat caller-fetched remote-tracking refs as canonical.
- Mutations prepare exact leased Git pushes by default; `--execute` runs the
  same argv with caller-owned Git configuration.
- A caller can claim a batch for offline work; overlapping callers may win
  disjoint subsets but never the same item.
- Claims expire after two hours, ordinary mutations do not renew them, and
  renewal, drop, expiry, and forced takeover are explicit and auditable.
- Builder handover, reviewer verdict, and landing evidence consist only of
  commit IDs verified in local Git repositories.
- Prepared multi-ref transactions remain reachable, survive concurrent
  refresh, and confirm only exact fetched refs.
- The board migrates from format 2 to 3 without rewriting existing item
  histories; incompatible readers and writers refuse with guidance.
- Shared WIP coordination, provider authentication, provider writes, and
  repeated lane warnings are removed from the core workflow.
- Documentation and tests cover the redesigned lifecycle and migration.
- The repository's full CI passes under its GitHub coverage sandbox.

# Evidence

Implementation: PR #90 head
Landing: PR #90 merge
Verification: repository CI on the implementation head and merge queue

Commit IDs are recorded by the workflow transitions, not duplicated here.
