--- Native storage workflow, separate from the legacy offline transport guide.
local BODY < const > = [[
Native format 6 stores the board on refs/heads/state. The board/format marker
selects this layout; a partially uploaded state branch never activates it.

For an isolated local test board:
  gitboard init --dir /path/to/test-board --local --format 6
  gitboard new "Proof item" --dir /path/to/test-board

On an activated remote board, the workflow remains refresh, claim, confirm,
compose a draft, publish, refresh. Claims are outside drafts. A receipt says
an attempt was published; the current claim record determines authority now.

Shell publication:
  gitboard publish TRANSACTION --execute
  gitboard refresh --execute

Connector publication:
  gitboard publish TRANSACTION --plan attempt.literal --repository OWNER/REPO
  gitboard publish --from-plan attempt.literal --call 0
Render each subsequent indexed call from the same saved plan. Execute it through
the GitHub connector, replacing symbolic prior-call SHA references with the actual
returned values. A draft creates one tree/commit per transition and advances state
once. Deletions rebuild the affected tree without requiring a null literal value.
Re-render the final call immediately before executing it: its deadline must still
hold. A stale branch rejects the non-forced update; prepare a new attempt after
refreshing, never combine calls from different attempts.
  gitboard publish --from-plan attempt.literal --published RETURNED_COMMIT_SHA
  gitboard refresh --execute
The connector chooses the physical Git author. A canonical Gitboard-Author literal
in the commit message preserves the logical session author and is checked when
confirming the complete ordered history.

Research evidence:
  gitboard take ITEM --result
This records published item state; speculative draft state must publish first.
Verdicts and completion keep the exact evidence identity and item attribution.

Migration is explicit:
  gitboard migrate6 plan --checkpoint checkpoint.literal
  gitboard migrate6 verify-source --checkpoint checkpoint.literal
Planning writes only local candidate objects and a checkpoint. It never cuts over
the board. Before the final snapshot, legacy ref creation, updates and deletion
must be blocked for every writer. Activation requires an exact source-ref-set
recheck and a shell atomic update of state and the format marker. The release must
support both old and new layouts before a pin changes. After native writes begin,
the old refs are an archive, not a rollback target.
]]
local record doctrine_native
  BODY: string
end
local M: doctrine_native = {BODY = BODY}
return M
