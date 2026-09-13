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
Re-render the final call immediately before executing it: its expected-head and
deadline guards must still hold. A stale branch rejects the non-forced update; prepare a new attempt after
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
the board. An offline checkpoint cannot acquire a retroactive freeze proof.
For a production snapshot, the owner first installs the legacy-write ruleset:
  gitboard migrate6 plan --remote origin --freeze-ruleset ID --checkpoint frozen.literal
This explicitly queries the ruleset through authenticated gh before and after
a fresh fetch. The supported ruleset covers items/**, ended/**, claim-batches/**,
and board/seq, refuses creation/update/deletion, and has no bypass or exclusions.
It also PROVES the fence bites: under items/**, ended/** and claim-batches/** it
attempts to create, force and delete a throwaway ref and requires every attempt
refused, recording each refusal in the checkpoint. An accepted attempt disproves
the freeze, and the ref it made is deleted again.
Inspect staged pushes, then execute only when the cutover is ready:
  gitboard migrate6 activation-plan --checkpoint frozen.literal --limit 100
  gitboard migrate6 publish --checkpoint frozen.literal --limit 100 --execute
Execution rechecks the live ruleset and complete source ref set, stages ancestors,
then atomically updates state and the format marker. Shell Git needs write
authentication; connector-only atomic activation is unavailable. The release must
support both old and new layouts before a pin changes. After native writes begin,
the old refs are an archive, not a rollback target.
]]
local record doctrine_native
  BODY: string
end
local M: doctrine_native = {BODY = BODY}
return M
