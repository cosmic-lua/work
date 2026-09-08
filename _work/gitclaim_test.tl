#!/usr/bin/env cosmic
-- Claim commits are prepared off canonical refs, preserve item ancestry, and
-- expose independent leased pushes. No test grants or uses network access.
local check = require("cosmic.check")
local child = require("cosmic.child")
local claim = require("_work.claim")
local fixture = require("_work.fixture")
local gitclaim = require("_work.gitclaim")
local gitclaim_cli = require("_work.gitclaim_cli")
local gitdone = require("_work.gitdone")
local gitobj = require("_work.gitobj")
local gitread = require("_work.gitread")
local refs = require("_work.refs")
local store = require("_work.store")

local NOW < const > = 2000000000
local BASE < const > = "0123456789012345678901234567890123456789"
local SESSION < const > = "0123456789abcdef0123456789abcdef"

local function rev(root: string, name: string): string
  local r = check.must(child.run({"git", "rev-parse", name}, {cwd = root}))
  assert(r.ok, r.stderr)
  return (r.stdout:gsub("%s+$", ""))
end

local function setup(name: string): store.Store, string, string
  local s = fixture.init_state_repo("claim-" .. name)
  local _parent, id = fixture.root_with_leaf(s)
  local local_ref = gitclaim.target_item_ref(id)
  local source = gitclaim.remote_item_ref("origin", id)
  fixture.git(s.root, {"update-ref", source, rev(s.root, local_ref)})
  return s, id, source
end

local function request(s: store.Store, id: string, source: string,
    batch: string, caller: string, action?: gitclaim.Action,
    now?: integer): gitclaim.Request
  return {root = s.root, id = id, source_ref = source,
    target_ref = gitclaim.target_item_ref(id), remote = "origin", batch = batch,
    caller = caller, action = action or "take", product_base = BASE,
    force = false, why = "", now = now or NOW}
end

local function publish_locally(s: store.Store, source: string,
    p: gitclaim.Prepared)
  fixture.git(s.root, {"update-ref", source, p.new_sha, p.old_sha})
end

local function test_take_prepares_without_moving_canonical_state()
  local s, id, source = setup("prepare")
  local before = rev(s.root, source)
  local p = check.must(gitclaim.prepare(request(s, id, source, "batch-a", "caller-a")))
  assert(p.status == "prepared" and p.old_sha == before and p.new_sha ~= before)
  assert(rev(s.root, source) == before, "canonical fetched ref did not move")
  assert(rev(s.root, p.staging_ref) == p.new_sha, "commit is staging-reachable")
  local staged = check.must(gitread.load(s.root, id, p.staging_ref, p.new_sha)).it
  assert(staged.claim == "caller-a" and staged.claim_base == BASE)
  assert(#staged.builders == 0, "acquisition is not builder involvement")
  assert(p.claim_root == p.new_sha and p.expires_at == NOW + claim.LEASE_S)
  assert(p.branch == claim.branch(id, p.new_sha))
  assert(table.concat(p.push_argv, " "):find("--force-with-lease="
      .. p.target_ref .. ":" .. before, 1, true))
end

local function test_already_owned_is_idempotent_and_does_not_renew()
  local s, id, source = setup("owned")
  local first = check.must(gitclaim.prepare(request(s, id, source,
        "batch-a", "caller-a")))
  publish_locally(s, source, first)
  local again = check.must(gitclaim.prepare(request(s, id, source,
        "batch-b", "caller-a", "take", NOW + 60)))
  assert(again.status == "already-owned" and again.new_sha == first.new_sha)
  assert(again.expires_at == first.expires_at and again.staging_ref == "")
end

local function test_renew_keeps_root_and_resets_deadline()
  local s, id, source = setup("renew")
  local first = check.must(gitclaim.prepare(request(s, id, source,
        "batch-a", "caller-a")))
  publish_locally(s, source, first)
  local renewal = check.must(gitclaim.prepare(request(s, id, source,
        "batch-b", "caller-a", "renew", NOW + 90)))
  local st = check.must(gitclaim.read_state(s.root, renewal.new_sha,
      "caller-a", BASE))
  assert(st.root == first.claim_root and st.control == renewal.new_sha)
  assert(st.expires_at == NOW + 90 + claim.LEASE_S,
    ("expiry %d expected %d, control %s"):format(st.expires_at,
      NOW + 90 + claim.LEASE_S, st.control))
  assert(renewal.branch == first.branch)
end

local function test_an_ordinary_item_commit_does_not_renew_the_claim()
  local s, id, source = setup("ordinary-does-not-renew")
  local first = check.must(gitclaim.prepare(request(s, id, source,
        "batch-a", "caller-a")))
  local tree = check.must(gitobj.tree_of(s.root, first.new_sha))
  local date = ("%d +0000"):format(NOW + 60 * 60)
  local ordinary = check.must(gitobj.commit_tree(s.root, {
        tree = tree, parents = {first.new_sha}, message = "handover item",
        author_name = "caller-a", author_email = "caller-a@board",
        author_date = date, committer_name = "gitboard",
        committer_email = "gitboard@board", committer_date = date, op = "handover",
      }))
  local st = check.must(gitclaim.read_state(s.root, ordinary, "caller-a", BASE))
  assert(st.control == first.new_sha and st.expires_at == NOW + claim.LEASE_S,
    "non-control commits never extend a lease")
end

local function test_expired_callers_prepare_competing_independent_attempts()
  local s, id, source = setup("race")
  local first = check.must(gitclaim.prepare(request(s, id, source,
        "batch-a", "caller-a")))
  publish_locally(s, source, first)
  local b = check.must(gitclaim.prepare(request(s, id, source,
        "batch-b", "caller-b", "take", NOW + claim.LEASE_S)))
  local old = check.must(gitclaim.prepare(request(s, id, source,
        "batch-c", "caller-a", "drop", NOW + claim.LEASE_S)))
  assert(b.old_sha == old.old_sha and b.new_sha ~= old.new_sha,
    "both may race the same item CAS; transport picks one")
end

local function test_force_take_is_audited_and_starts_a_new_lineage()
  local s, id, source = setup("force")
  local first = check.must(gitclaim.prepare(request(s, id, source,
        "batch-a", "caller-a")))
  publish_locally(s, source, first)
  local req = request(s, id, source, "batch-b", "caller-b", "take", NOW + 1)
  req.force = true
  local no, err = gitclaim.prepare(req)
  assert(no == nil and err:find("requires --why", 1, true))
  req.why = "caller-a is stuck"
  local forced = check.must(gitclaim.prepare(req))
  assert(forced.claim_root == forced.new_sha and forced.claim_root ~= first.claim_root)
  local msg = rev(s.root, forced.new_sha) -- proves it is a commit before cat-file below
  local body = check.must(child.run({"git", "show", "-s", "--format=%B", msg},
      {cwd = s.root}))
  assert(body.stdout:find("Claim-Reason: caller-a is stuck", 1, true))
  assert(body.stdout:find("Op: claim-force", 1, true))
end

local function test_drop_and_reviewer_reacquire_preserve_the_work_base()
  local s, id, source = setup("drop-review")
  local first = check.must(gitclaim.prepare(request(s, id, source,
        "batch-a", "builder")))
  publish_locally(s, source, first)
  local dropped = check.must(gitclaim.prepare(request(s, id, source,
        "batch-b", "builder", "drop", NOW + 1)))
  local released = check.must(gitread.load(s.root, id, dropped.staging_ref,
      dropped.new_sha)).it
  assert(released.claim == "" and released.claim_base == BASE,
    "drop clears only the lease holder, never the work lineage")
  publish_locally(s, source, dropped)

  local review_req = request(s, id, source, "batch-c", "reviewer",
    "take", NOW + 2)
  review_req.product_base = ""
  local reviewed = check.must(gitclaim.prepare(review_req))
  local review_item = check.must(gitread.load(s.root, id,
      reviewed.staging_ref, reviewed.new_sha)).it
  assert(review_item.claim == "reviewer" and review_item.claim_base == BASE,
    "reviewer acquisition inherits the original work base")
end

local function test_batch_is_best_effort_and_shares_one_deadline()
  local s, id, source = setup("batch")
  local missing = ("z"):rep(27)
  local good = request(s, id, source, "batch-a", "caller-a")
  local bad = request(s, missing, gitclaim.remote_item_ref("origin", missing),
    "batch-a", "caller-a")
  local result = gitclaim.prepare_batch({good, bad})
  assert(#result.prepared == 1 and result.prepared[1].expires_at
    == NOW + claim.LEASE_S)
  assert(result.refused[missing] ~= nil, "missing item is its own refusal")
end

local function test_confirm_uses_fetched_state_then_cleans_staging()
  local s, id, source = setup("confirm")
  local p = check.must(gitclaim.prepare(request(s, id, source,
        "batch-a", "caller-a")))
  assert(not gitclaim.confirm(s.root, source, p), "cannot confirm before fetch")
  publish_locally(s, source, p)
  assert(gitclaim.confirm(s.root, source, p))
  local found = check.must(refs.for_each_ref(s.root, {p.staging_ref}))
  assert(#found == 0, "confirmed staging ref is disposable")
end

local function test_prepared_claims_are_rediscoverable_after_process_exit()
  local s, id, source = setup("rediscover")
  local p = check.must(gitclaim.prepare(request(s, id, source,
        "batch-a", "caller-a")))
  local found = check.must(gitclaim.list_prepared(s.root, "upstream"))
  local rediscovered: gitclaim.Prepared = nil
  for _, candidate in ipairs(found) do
    if candidate.new_sha == p.new_sha then rediscovered = candidate end
  end
  assert(rediscovered ~= nil, "staged claim remains discoverable")
  assert(rediscovered.old_sha == p.old_sha
    and rediscovered.target_ref == p.target_ref
    and rediscovered.claim_root == p.claim_root
    and rediscovered.expires_at == p.expires_at)
  assert(rediscovered.push_argv[4] == "upstream"
    and rediscovered.push_argv[5] == p.staging_ref .. ":" .. p.target_ref)
end

-- Claims bind an item, not an open workflow state. Modern completed items
-- remain under `items`, and the CLI must preserve that historical namespace.
local function test_local_cli_claims_a_completed_item_in_its_existing_namespace()
  local s = fixture.init_state_repo("claim-ended-cli")
  local _parent, id = fixture.root_with_leaf(s)
  assert(gitdone.cmd_done(s, id, "completed", false, "") == 0)
  local target = gitclaim.target_item_ref(id)
  assert(rev(s.root, target) ~= "")
  assert(gitclaim_cli.cmd_claim(s, {id}, "take", SESSION, "origin", "",
      false, "", false) == 0)
  local got = check.must(store.load(s, id))
  assert(got.claim == SESSION, "the completed item acquired the claim")
  assert(rev(s.root, target) == s.leased_sha[id],
    "the claim advanced the item's existing canonical ref")
  local ended_ref = check.must(refs.read_ref(s.root,
      gitclaim.target_item_ref(id, true)))
  assert(ended_ref == refs.ZERO_SHA,
    "claiming completed work never manufactures an ended ref")
end

-- Process-exit recovery must preserve the lane encoded by the staged item,
-- because the staging ref grammar intentionally contains only batch and id.
local function test_completed_claim_retry_and_confirmation_keep_the_ended_ref()
  local s = fixture.init_state_repo("claim-ended-retry")
  local _parent, id = fixture.root_with_leaf(s)
  assert(gitdone.cmd_done(s, id, "completed", false, "") == 0)
  local target = gitclaim.target_item_ref(id, true)
  local original = gitclaim.target_item_ref(id)
  local original_sha = rev(s.root, original)
  fixture.git(s.root, {"update-ref", target, original_sha})
  fixture.git(s.root, {"update-ref", "-d", original})
  local _closed, _cerr = store.close(s)
  s = check.must(store.open(s.root))
  local source = gitclaim.remote_item_ref("origin", id, true)
  fixture.git(s.root, {"update-ref", source, rev(s.root, target)})
  local req = request(s, id, source, "batch-ended", SESSION)
  req.target_ref = target
  local first = check.must(gitclaim.prepare(req))
  assert(first.target_ref == target)
  local retried = check.must(gitclaim.prepare(req))
  assert(retried.new_sha == first.new_sha and retried.target_ref == target,
    "same-process retry reuses the ended-item CAS")
  local found = check.must(gitclaim.list_prepared(s.root, "origin"))
  local recovered: gitclaim.Prepared = nil
  for _, candidate in ipairs(found) do
    if candidate.new_sha == first.new_sha then recovered = candidate end
  end
  assert(recovered ~= nil and recovered.target_ref == target,
    "Git-only recovery infers the canonical ended namespace")
  publish_locally(s, source, first)
  assert(gitclaim.confirm(s.root, source, first))
end
