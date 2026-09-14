--- Native storage publication and migration workflow.
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
Observe the remote state head immediately before rendering the final call, and
pass it with --head SHA. Its expected-head and deadline guards must still hold.
These are local checks; the connector has no expected-head or deadline argument.
A stale branch rejects the non-forced update; prepare a new attempt after
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
For a production snapshot, prepare sacrificial refs before enabling the fence:
  gitboard migrate6 prepare-freeze --remote origin --checkpoint frozen.literal
This saves a probe manifest before creating separate update and delete refs in
each globbed legacy namespace. The owner then enables the legacy-write ruleset:
  gitboard migrate6 plan --remote origin --freeze-ruleset ID --checkpoint frozen.literal
This explicitly queries the ruleset through authenticated gh before and after
a fresh fetch. The supported ruleset covers items/**, ended/**, claim-batches/**,
and board/seq, refuses creation/update/deletion, and has no bypass or exclusions.
It also proves the fence bites: under items/**, ended/** and claim-batches/** it
attempts to create an absent ref, change an existing probe tip, and delete a
different existing probe ref. Every attempt must receive a ref-specific ruleset
refusal; authentication, network and missing-ref failures are not freeze proof.
Only the exact manifest-owned refs are excluded from replay. The probe refs stay
frozen as archive; an accepted attempt invalidates the freeze.
Inspect staged pushes, then execute only when the cutover is ready:
  gitboard migrate6 activation-plan --checkpoint frozen.literal --limit 100
  gitboard migrate6 publish --checkpoint frozen.literal --limit 100 --execute
Execution rechecks the live ruleset and complete source ref set, stages ancestors,
then atomically updates state and the format marker. Shell Git needs write
authentication; connector-only atomic activation is unavailable. Release the
native-only binary, run migration with that binary, activate, then land the pin
immediately. Normal verbs refuse format 5; migration retains its legacy reader.
The short activation-to-pin outage is deliberate. After native writes begin,
the old refs remain an archive, not a rollback target.
]]
local record doctrine_native
  BODY: string
end
local M: doctrine_native = {BODY = BODY}
return M
