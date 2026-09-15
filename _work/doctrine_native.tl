--- Native storage publication and migration workflow.
local BODY < const > = [[
Native format 6 stores the board on refs/heads/state. The board/format marker
selects this layout; a partially uploaded state branch never activates it.

For an isolated local test board:
  gitboard init --dir /path/to/test-board --local --format 6
  gitboard new "Proof item" --dir /path/to/test-board
Local mode auto-confirms every mutation immediately against refs/heads/state.
It retains no composition for snapshot --check or a later publish command.

On an activated remote board, refresh before composing. Ordinary verbs replace
one clone-local final-board snapshot whose sole parent is the fetched canonical
head. Publish a claim and fetch its confirmation before dependent work. The
current claim record, rather than a proposed or merely submitted commit,
determines authority.

Shell publication:
  gitboard snapshot --check
  gitboard publish COMMIT

Connector publication:
  gitboard publish COMMIT --protocol begin
  gitboard publish COMMIT --protocol trees
  gitboard publish COMMIT --protocol commit --returned-tree SHA
  gitboard publish COMMIT --protocol candidate --candidate SHA
  gitboard publish COMMIT --protocol update --head SHA
A Work session invokes the emitted GitHub connector calls in that order. Teal
freezes the local snapshot, saves the returned commit SHA, and checks the exact
destination head and claim deadline before the one non-forced ref update.
Deletions may require multiple tree calls. A changed head conflicts the entire
snapshot. There is no automatic rebase, replay, or partial-prefix confirmation.
The `gitboard.publicationBranch` config redirects publication and recovery for
isolated validation branches. Leave it unset for production `state` publication.
The `gitboard.publicationRepository` config supplies the connector repository
identity when it cannot be derived from the configured remote URL.

If an update response is lost, fetch and reconcile the saved candidate before
retrying anything. A candidate or updating restart never creates another commit.
Only the same known candidate may retry, and only while the fetched head is the
original parent and its claim deadline is live. Confirmation checks exact parent,
tree, message, logical author, and canonical first-parent reachability.
The connector chooses the physical Git author. A canonical Gitboard-Author literal
in the commit message preserves the logical session author and is checked during
confirmation.

Research evidence:
  gitboard take ITEM --result
This records published item state; local snapshot state must publish first.
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
