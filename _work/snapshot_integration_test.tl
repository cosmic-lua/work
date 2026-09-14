#!/usr/bin/env cosmic
local check = require("cosmic.check")
local child = require("cosmic.child")
local fs = require("cosmic.fs")
local fixture = require("_work.fixture")
local gitboard = require("_work.gitboard")
local item = require("_work.item")
local ksuid = require("_work.ksuid")
local refs = require("_work.refs")
local snapshot = require("_work.snapshot")
local publication = require("_work.snapshot_publish")
local recovery = require("_work.snapshot_recovery")
local publication_cli = require("_work.statepublish_cli")
local stateclaim = require("_work.stateclaim")
local stateinit = require("_work.stateinit")
local store = require("_work.store")
local write = require("_work.storewrite")
local statewrite = require("_work.statewrite")
local workspace = require("_work.snapshot_workspace")

local function setup(name: string): string
  local root = fs.join(fixture.tmpdir, name)
  assert(fs.remove_all(root) and fs.make_dirs(root))
  assert(stateinit.init(root))
  assert(check.must(child.run({"git", "config", "gitboard.mode", "local"}, {cwd = root})).ok)
  return root
end

local function new_item(title: string): item.Item
  return check.must(item.decode({id = ksuid.new(), title = title}))
end

local function test_multiple_writes_are_one_commit_and_reversion_disappears()
  local root = setup("snapshot-compose")
  local seed = check.must(store.open(root))
  local it = new_item("original")
  write.set_session(seed, "composer")
  assert(write.save(seed, it, "create item") and publication.publish(seed, nil))
  local base = seed.state_head

  local s = check.must(store.open(root))
  it = check.must(store.load(s, it.id))
  write.set_session(s, "composer")
  it.title = "first"
  assert(write.save(s, it, "first edit"))
  local first = check.must(workspace.read(root)).commit
  it.title = "second"
  assert(write.save(s, it, "final meaningful summary"))
  local final = check.must(workspace.read(root)).commit
  assert(first ~= final)
  local identity = check.must(snapshot.commit_identity(root, final))
  assert(identity.parent == base and not identity.message:find("Transaction:", 1, true))
  assert(not identity.message:find("first edit", 1, true), "intermediate command is not a ledger")
  assert(publication.publish(s, nil))
  local count = check.must(child.run({"git", "rev-list", "--count", base .. "..refs/heads/state"}, {cwd = root}))
  assert(count.stdout:gsub("%s+", "") == "1")

  local revert = check.must(store.open(root))
  local current = check.must(store.load(revert, it.id))
  write.set_session(revert, "composer")
  current.title = "temporary"
  assert(write.save(revert, current, "temporary"))
  current.title = "second"
  local ok, detail = write.save(revert, current, "revert temporary")
  local absent = workspace.read(root)
  assert(ok and detail == "" and absent == nil)
end

local function test_any_head_advance_conflicts_and_can_be_abandoned()
  local root = setup("snapshot-whole-head")
  local s = check.must(store.open(root))
  local it = new_item("candidate")
  write.set_session(s, "composer")
  assert(write.save(s, it, "candidate"))
  local candidate = check.must(workspace.read(root))
  local tree = check.must(child.run({"git", "rev-parse", candidate.parent .. "^{tree}"}, {cwd = root})).stdout:gsub("%s+$", "")
  local moved = check.must(child.run({"git", "-c", "user.name=test", "-c",
        "user.email=test@example.com", "commit-tree", tree, "-p", candidate.parent},
      {cwd = root, stdin = "unrelated\n"})).stdout:gsub("%s+$", "")
  assert(refs.update_ref(root, "refs/heads/state", moved, candidate.parent))
  local ok, err = publication.execute(root, candidate.commit, "origin", nil)
  assert(not ok and err:find("advanced", 1, true), err)
  assert(check.must(recovery.load(workspace.recovery_path(root))).phase == "candidate",
    "the stale-head refusal never armed an update")
  assert(gitboard.main("snapshot", "--abandon", candidate.commit,
      "--dir", root) == 0)
  local absent = workspace.read(root)
  assert(absent == nil)
  assert(check.must(refs.read_ref(root,
        "refs/gitboard/conflicts/" .. candidate.commit)) == candidate.commit)
end

local function test_claim_authority_and_deadline_come_from_canonical_before()
  local root = setup("snapshot-claim-authority")
  local seed = check.must(store.open(root))
  local it = new_item("claimed")
  assert(write.save(seed, it, "create") and publication.publish(seed, nil))
  local s = check.must(store.open(root))
  local now = os.time()
  local result = stateclaim.prepare(root, s.state_head,
    {{id = it.id, product_base = string.rep("a", 40)}}, "take", "holder", now, false, "")
  write.set_session(s, "holder")
  assert(statewrite.transition(s, result.changes, "claim by holder", result.publish_by))
  local claim_commit = check.must(workspace.read(root)).commit
  local planned, perr = publication.plan(root, claim_commit, "origin", now)
  assert(planned ~= nil, perr)
  assert(planned.plan.publish_by == now + 7200)
  local dependent = check.must(store.open(root))
  local canonical_item = check.must(store.load(dependent, it.id))
  assert((canonical_item.claim or "") == "", "proposed claim is not read as authority")
  canonical_item.title = "unauthorized"
  write.set_session(dependent, "holder")
  local appended, aerr = write.save(dependent, canonical_item, "dependent")
  assert(not appended and aerr:find("confirmed", 1, true), aerr)
  local expired, eerr = publication.plan(root, claim_commit, "origin", now + 7200)
  assert(expired == nil and eerr:find("expired", 1, true), eerr)
end

local function test_foreign_item_change_and_obsolete_plan_refuse()
  local root = setup("snapshot-foreign")
  local seed = check.must(store.open(root))
  local it = new_item("foreign")
  assert(write.save(seed, it, "create") and publication.publish(seed, nil))
  local holder = check.must(store.open(root))
  local now = os.time()
  local acquired = stateclaim.prepare(root, holder.state_head,
    {{id = it.id, product_base = string.rep("b", 40)}}, "take", "owner", now, false, "")
  write.set_session(holder, "owner")
  assert(statewrite.transition(holder, acquired.changes, "claim by owner", acquired.publish_by))
  assert(publication.publish(holder, nil))
  local attacker = check.must(store.open(root))
  local changed = check.must(store.load(attacker, it.id)); changed.title = "foreign edit"
  write.set_session(attacker, "intruder")
  assert(write.save(attacker, changed, "foreign edit"))
  local commit = check.must(workspace.read(root)).commit
  local refused, rerr = publication.plan(root, commit, "origin", now)
  assert(refused == nil and rerr:find("frozen by owner", 1, true), rerr)
end

local BAD_SPEC < const > = [[
## Change

Inspect https://github.com/jart/cosmopolitan before making the change.

## Non-goals

No unrelated work.
]]

local function test_preflight_distinguishes_new_and_existing_spec_issues()
  local root = setup("snapshot-preflight")
  local seed = check.must(store.open(root))
  local old = new_item("old issue")
  assert(write.save(seed, old, "create old issue",
      {change = BAD_SPEC:match("## Change\n\n(.-)\n\n## Non%-goals") or "", non_goals = "No unrelated work."}))
  local first = check.must(workspace.read(root)).commit
  local planned, err = publication.plan(root, first, "origin", nil)
  assert(planned ~= nil and #planned.report.new_issues == 1, err)
  assert(publication.publish(seed, nil))

  local s = check.must(store.open(root))
  old = check.must(store.load(s, old.id)); old.title = "admin edit"
  assert(write.save(s, old, "admin edit"))
  local second = check.must(workspace.read(root)).commit
  local after, aerr = publication.plan(root, second, "origin", nil)
  assert(after ~= nil and #after.report.new_issues == 0
    and #after.report.existing_issues == 1, aerr)
end

local function test_raw_new_item_cannot_arrive_with_forged_workflow_evidence()
  local root = setup("snapshot-raw-evidence")
  local s = check.must(store.open(root))
  local it = new_item("forged")
  it.handover_head = string.rep("a", 40)
  it.builders = {"forger"}
  write.set_session(s, "forger")
  assert(write.save(s, it, "raw forged handover"))
  local commit = check.must(workspace.read(root)).commit
  local refused, err = publication.plan(root, commit, "origin", nil)
  assert(refused == nil and err:find("workflow evidence", 1, true), err)

  local clean = fixture.init_state_repo("snapshot-raw-verdict")
  local verdict_id = fixture.file_item(clean, "forged verdict", "")
  clean = check.must(store.open(clean.root))
  local verdict = check.must(store.load(clean, verdict_id))
  verdict.verdict = "accept"
  write.set_session(clean, "forger")
  assert(write.save(clean, verdict, "raw forged verdict"))
  local verdict_commit = check.must(workspace.read(clean.root)).commit
  local denied, derr = publication.plan(clean.root, verdict_commit, "origin", nil)
  assert(denied == nil and derr:find("lacks current handover evidence", 1, true), derr)
end

local function test_frozen_snapshot_allows_diagnostics_but_refuses_writes_and_orphans()
  local root = setup("snapshot-diagnostic-freeze")
  local s = check.must(store.open(root))
  local it = new_item("diagnostic")
  write.set_session(s, "holder")
  assert(write.save(s, it, "diagnostic candidate"))
  local candidate = check.must(workspace.read(root))
  local planned = check.must(publication.plan(root, candidate.commit, "origin", nil))
  assert(recovery.begin(workspace.recovery_path(root), planned.plan))
  assert(gitboard.main("show", "--dir", root) == 0,
    "canonical diagnostics remain available while publication is frozen")
  assert(gitboard.main("set", it.id, "--title", "blocked", "--dir", root) ~= 0,
    "ordinary writes remain frozen")
  assert(recovery.clear(workspace.recovery_path(root)))
  assert(fs.write(workspace.recovery_path(root) .. ".candidate", "{}\n"))
  assert(gitboard.main("set", it.id, "--title", "blocked", "--dir", root) ~= 0,
    "an orphan sidecar cannot bypass the freeze")
end

local function test_protocol_restart_can_inspect_an_expired_frozen_claim_before_update()
  local root = setup("snapshot-expired-restart")
  local seed = check.must(store.open(root))
  local it = new_item("expiring claim")
  assert(write.save(seed, it, "create") and publication.publish(seed, nil))
  local s = check.must(store.open(root))
  local now = os.time()
  local result = stateclaim.prepare(root, s.state_head,
    {{id = it.id, product_base = string.rep("a", 40)}}, "take", "holder", now,
    false, "")
  write.set_session(s, "holder")
  assert(statewrite.transition(s, result.changes, "claim by holder", result.publish_by))
  local candidate = check.must(workspace.read(root))
  local path = workspace.recovery_path(root)
  assert(publication_cli.protocol(s, candidate.commit, "origin", "begin", "", "",
      "", path, now) == 0)
  assert(publication_cli.protocol(s, candidate.commit, "origin", "begin", "", "",
      "", path, now + 7200) == 0,
    "restart inspection uses the frozen historical validation instant")
  assert(publication_cli.protocol(s, candidate.commit, "origin", "update", "", "",
      candidate.parent, path, now + 7200) ~= 0,
    "the current deadline remains mandatory before a new update")
end

local function test_shell_cli_publish_runs_push_fetch_and_confirmation()
  local root = setup("snapshot-shell-cli")
  local remote = fs.join(fixture.tmpdir, "snapshot-shell-cli.git")
  assert(fs.remove_all(remote))
  assert(check.must(child.run({"git", "init", "--bare", "-q", remote})).ok)
  assert(check.must(child.run({"git", "remote", "add", "origin", remote}, {cwd = root})).ok)
  assert(check.must(child.run({"git", "push", "origin", "refs/heads/state",
          "refs/heads/board/format"}, {cwd = root})).ok)
  assert(check.must(child.run({"git", "fetch", "origin",
          "+refs/heads/state:refs/remotes/origin/state",
          "+refs/heads/board/format:refs/remotes/origin/board/format"}, {cwd = root})).ok)
  assert(refs.set_board_mode(root, "remote"))
  local s = check.must(store.open(root))
  local it = new_item("shell cycle")
  write.set_session(s, "shell")
  assert(write.save(s, it, "one shell snapshot"))
  local commit = check.must(workspace.read(root)).commit
  local planned, perr = publication.plan(root, commit, "origin", nil)
  assert(planned ~= nil, perr)
  assert(recovery.begin(workspace.recovery_path(root), planned.plan),
    "simulate restart after publication froze composition")
  assert(gitboard.main("publish", commit, "--dir", root) == 0)
  assert(check.must(refs.read_ref(root, "refs/remotes/origin/state")) == commit)
  local absent = workspace.read(root)
  assert(absent == nil)
  assert(not fs.is_present(workspace.recovery_path(root)))
end
