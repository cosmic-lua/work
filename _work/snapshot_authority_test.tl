#!/usr/bin/env cosmic
--- Raw snapshot authority, attribution, and recovery-clock regressions.
local boardread = require("_work.boardread")
local boardtree = require("_work.boardtree")
local check = require("cosmic.check")
local claim = require("_work.claim")
local flow = require("_work.commit_flow_fixture")
local fixture = require("_work.fixture")
local git = require("_work.singlehead_git")
local graph = require("_work.gitgraph")
local item = require("_work.item")
local publication = require("_work.snapshot_publish")
local protocol = require("_work.snapshot_protocol")
local recovery = require("_work.snapshot_recovery")
local refs = require("_work.refs")
local snapshot = require("_work.snapshot")
local store = require("_work.store")
local write = require("_work.storewrite")
local workspace = require("_work.snapshot_workspace")

local function denied(s: store.Store, commit: string, now: integer,
    needle: string)
  local planned, err = publication.plan(s.root, commit, "origin", now)
  assert(planned == nil and err:find(needle, 1, true), err)
end

local function claim_blob(holder: string, acquired: integer,
    product_base: string, id?: string): string
  return check.must(boardtree.encode_claim({id = id or boardtree.mint_claim_id(),
        holder = holder, acquired_at = acquired, renewed_at = acquired,
        expires_at = acquired + claim.LEASE_S, product_base = product_base}))
end

local function claim_commit(s: store.Store, id: string, author: string,
    content: string, message: string): string
  return check.must(workspace.compose(s.root, s.state_head, s.state_head,
      author, {{path = "claims/" .. id, mode = "100644", content = content,
          delete = false}}, message))
end

local function reauthor(root: string, commit: string, epoch: integer,
    summary: string): string
  local identity = check.must(snapshot.commit_identity(root, commit))
  local author = identity.author
  author.date = tostring(epoch) .. " +0000"
  local message = check.must(snapshot.message(summary, author))
  return check.must(git.text(root,
      {"commit-tree", identity.tree, "-p", identity.parent}, message, {
        GIT_AUTHOR_NAME = author.name, GIT_AUTHOR_EMAIL = author.email,
        GIT_AUTHOR_DATE = author.date, GIT_COMMITTER_NAME = "gitboard",
        GIT_COMMITTER_EMAIL = "gitboard@localhost",
        GIT_COMMITTER_DATE = author.date}))
end

local function test_raw_claim_acquisition_cannot_rotate_an_active_lease()
  local s, id, product = flow.fresh("snapshot-raw-claim-acquisition")
  assert(flow.claim(s, id, flow.BUILDER, product) == 0)
  local old = check.must(boardread.list(s.root, s.state_head)).claims_by_id[id]
  local now = old.renewed_at

  local takeover = claim_commit(s, id, flow.OTHER,
    claim_blob(flow.OTHER, now, product.base),
    "raw takeover\n\nForce-Why: attempted repair")
  denied(s, takeover, now, "item is claimed by")
  assert(workspace.clear(s.root, takeover))

  local new_identity = claim_commit(s, id, flow.BUILDER,
    claim_blob(flow.BUILDER, now, product.base), "raw claim rotation")
  denied(s, new_identity, now, "use renew or drop")
  assert(workspace.clear(s.root, new_identity))

  local new_product = claim_commit(s, id, flow.BUILDER,
    claim_blob(flow.BUILDER, old.acquired_at, product.head, old.id),
    "raw product-base rotation")
  denied(s, new_product, now, "invalid claim renewal")
end

local function test_raw_future_claim_deletion_is_not_a_drop_bypass()
  local s, id, product = flow.fresh("snapshot-raw-future-drop")
  assert(flow.claim(s, id, flow.BUILDER, product) == 0)
  local old = check.must(boardread.list(s.root, s.state_head)).claims_by_id[id]
  local commit = check.must(workspace.compose(s.root, s.state_head, s.state_head,
      flow.BUILDER, {{path = "claims/" .. id, mode = "100644", content = "",
          delete = true}}, "raw drop"))
  local authored_too_early = old.renewed_at - claim.FUTURE_SKEW_S - 1
  local historical = reauthor(s.root, commit, authored_too_early, "raw drop")
  denied(s, historical, old.renewed_at, "more than five minutes in the future")
end

local function changed_spec(s: store.Store, id: string, author: string,
    attributed: boolean): string
  local it = check.must(store.load(s, id))
  if attributed then assert(item.record_involvement(it.speccers, author)) end
  write.set_session(s, author)
  assert(write.save(s, it, "raw spec change", {
        change = "Changed by the logical author.",
        non_goals = "Preserve all unrelated behavior."}))
  return check.must(workspace.read(s.root)).commit
end

local function test_raw_spec_delta_requires_its_named_author_attribution()
  local missing, missing_id, _ = flow.fresh("snapshot-raw-spec-missing")
  local omitted = changed_spec(missing, missing_id, flow.OTHER, false)
  denied(missing, omitted, os.time(), "spec change lacks author attribution")

  local valid, valid_id, _ = flow.fresh("snapshot-raw-spec-valid")
  local attributed = changed_spec(valid, valid_id, flow.OTHER, true)
  local planned, err = publication.plan(valid.root, attributed, "origin", os.time())
  assert(planned ~= nil, err)
end

local function test_anonymous_raw_spec_delta_remains_supported()
  local s, id, _ = flow.fresh("snapshot-raw-spec-anonymous")
  local commit = changed_spec(s, id, "", false)
  local identity = check.must(snapshot.commit_identity(s.root, commit))
  assert(identity.author.name == "gitboard")
  local planned, err = publication.plan(s.root, commit, "origin", os.time())
  assert(planned ~= nil, err)
end

local function test_named_new_item_spec_records_its_author()
  local s = fixture.init_state_repo("snapshot-new-spec-author")
  local body = {change = "Carry the initial specification.",
    non_goals = "Do not change unrelated behavior."}
  assert(graph.cmd_new(s, "Named specification", "", body, "", false,
      "", "", "", flow.OTHER) == 0)
  local found: item.Item | nil = nil
  for _, candidate in ipairs(check.must(store.list(s))) do
    if candidate.title == "Named specification" then found = candidate end
  end
  assert(found ~= nil and #(found.speccers or {}) == 1
    and found.speccers[1] == flow.OTHER)
end

local function claimed_item_change(name: string): store.Store, string,
  flow.Product, boardtree.Claim, string
  local s, id, product = flow.fresh(name)
  assert(flow.claim(s, id, flow.BUILDER, product) == 0)
  local lease = check.must(boardread.list(s.root, s.state_head)).claims_by_id[id]
  local it = check.must(store.load(s, id)); it.title = "Changed title"
  write.set_session(s, flow.BUILDER)
  assert(write.save(s, it, "change title"))
  return s, id, product, lease, check.must(workspace.read(s.root)).commit
end

local function test_initial_plan_rejects_unrecoverable_logical_author_dates()
  local future, _fid, _fp, future_lease, proposed =
  claimed_item_change("snapshot-future-author")
  local beyond_lease = future_lease.expires_at + 1
  local future_commit = reauthor(future.root, proposed, beyond_lease,
    "future logical author")
  denied(future, future_commit, future_lease.renewed_at,
    "prepared claim expired before publication")

  local old, _oid, _op, old_lease, old_proposed =
  claimed_item_change("snapshot-old-author")
  local before_skew = old_lease.renewed_at - claim.FUTURE_SKEW_S - 1
  local old_commit = reauthor(old.root, old_proposed, before_skew,
    "old logical author")
  denied(old, old_commit, old_lease.renewed_at,
    "more than five minutes in the future")

  local boundary = reauthor(old.root, old_proposed,
    old_lease.renewed_at - claim.FUTURE_SKEW_S,
    "logical author at skew boundary")
  local planned, err = publication.plan(old.root, boundary, "origin",
    old_lease.renewed_at)
  assert(planned ~= nil, err)
end

local function test_lost_response_still_confirms_after_real_lease_expiry()
  local s, id, product = flow.fresh("snapshot-expired-confirmation")
  local now = os.time()
  local acquired = now - claim.LEASE_S - 60
  local raw_claim = claim_commit(s, id, flow.BUILDER,
    claim_blob(flow.BUILDER, acquired, product.base), "historical claim")
  local claim_at_time = reauthor(s.root, raw_claim, acquired,
    "historical claim")
  local claim_parent = check.must(snapshot.commit_identity(s.root,
      claim_at_time)).parent
  assert(publication.plan(s.root, claim_at_time, "origin", acquired))
  assert(workspace.clear(s.root, raw_claim))
  assert(refs.update_ref(s.root, "refs/heads/state", claim_at_time, claim_parent))

  local changed = check.must(store.open(s.root))
  local it = check.must(store.load(changed, id)); it.title = "Historical edit"
  write.set_session(changed, flow.BUILDER)
  assert(write.save(changed, it, "historical edit"))
  local current_dated = check.must(workspace.read(s.root)).commit
  local authored = acquired + 1
  local commit = reauthor(s.root, current_dated, authored, "historical edit")
  assert(workspace.clear(s.root, current_dated))
  assert(workspace.retain(s.root, commit))
  local planned = check.must(publication.plan(s.root, commit, "origin", authored))
  local path = workspace.recovery_path(s.root)
  local state = check.must(recovery.begin(path, planned.plan))
  state = check.must(recovery.record_candidate(path, planned.plan, commit))
  assert(protocol.arm_update(path, planned.plan, state, planned.plan.parent,
      authored))
  assert(refs.update_ref(s.root, "refs/heads/state", commit,
      planned.plan.parent))
  local outcome, err = publication.reconcile_saved(s.root, commit, "origin",
    path, commit)
  assert(outcome ~= nil and outcome.status == "confirmed", err)
end
