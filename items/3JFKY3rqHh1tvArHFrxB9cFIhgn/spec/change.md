Resolve review ranges and worktree placement from the item's repository facts.
This is the combined implementation of B9cF_Ihgn and 2Exm_9CJZ requested by
the caller; the linked-root evidence in a65J_xJWz supplies the path regression.

For a product review, resolve the target base from item.base when present,
otherwise the existing locally cached default-branch resolution. Resolve
that ref and the exact handover to commits, then compute their merge base.
Render the review's range using the resolved target commit and exact handover
with three dots so forward-merged upstream changes are excluded. Refuse
missing refs, unrelated histories, ambiguous merge bases, or a computed
merge base that cannot be proved an ancestor of the handover; name the
expected base/ref and handover plus the reason. Do not fetch. A target tip
that advanced independently is allowed when its merge base is valid: the
ancestry invariant applies to the computed merge base, not that mutable tip.
Preserve the immutable claim_base fact and classifier behavior. Only the
range expression in each review script may change; other script prose is
outside this item. Research handovers retain their current behavior.

For worktree placement, repository_map.resolve must canonicalize explicit
and configured linked-worktree selections to their registered primary
product checkout before claim.worktree constructs the destination. Persist
that primary path when remembering an explicit override. Keep validate's
exact selected-root semantics: adoption and preparation receipts validate
the actual linked checkout. Use registered Git worktree metadata, not the
parent of a git-common-dir guessed to be a product checkout. If no usable
nonbare primary is available, refuse clearly.

Preserve <primary>/../wt/work/<handle>/<claim-root-short>. Before creating
directories or branches, refuse a computed destination equal to or beneath
any registered same-repository worktree. Name destination and conflicting
worktree, account for path-component boundaries and resolved filesystem
ancestors, and leave no partially created branch/directory on this refusal.
Builder creation, review creation, brief paths, and existing-worktree checks
must use the same resolved root.

Regression cases: a simple review branch; a branch merging its base forward
whose range excludes upstream-only changes; an independently advanced target
with a valid merge base; missing/unrelated base refusal naming both sides;
explicit item.base overriding default. For paths, run from inside another
worktree with a primary mapping, supply an explicit linked --repo-dir, and
read a previously recorded linked mapping. Assert sibling placement and
matching brief paths. Exercise a nesting refusal, including a path-prefix
noncollision, and retain adoption/receipt validation of actual linked roots.
