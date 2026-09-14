#!/usr/bin/env cosmic
local check = require("cosmic.check")
local child = require("cosmic.child")
local fs = require("cosmic.fs")
local proc = require("cosmic.proc")
local time = require("cosmic.time")
local flow = require("_work.commit_flow_fixture")
local fixture = require("_work.fixture")
local gitboard = require("_work.gitboard")
local projection = require("_work.stateplan_git")
local publication = require("_work.snapshot_publish")
local recovery = require("_work.snapshot_recovery")
local refs = require("_work.refs")
local snapshot = require("_work.snapshot")
local snapshot_lock = require("_work.snapshot_lock")
local stateclaim = require("_work.stateclaim")
local statewrite = require("_work.statewrite")
local store = require("_work.store")
local tx = require("_work.statetransaction")
local write = require("_work.storewrite")
local workspace = require("_work.snapshot_workspace")

local function proposal(name: string): store.Store, string
  local s, id, _product = flow.fresh(name)
  local it = check.must(store.load(s, id))
  write.set_session(s, flow.OTHER)
  it.title = "snapshot A"
  assert(write.save(s, it, "prepare snapshot A"))
  return s, id
end

local function test_compose_cannot_cross_the_public_freeze_boundary()
  local s, id = proposal("serialized-freeze")
  local a = check.must(workspace.read(s.root)).commit
  local planned = check.must(publication.plan(s.root, a, "origin", nil))
  local original = projection.apply
  local attempted = false
  projection.apply = function(root: string, base: string,
      changes: {tx.Change}): string | nil, string
    attempted = true
    local frozen, err = publication.start(root, planned.plan)
    assert(frozen == nil and err:find("active in this process", 1, true), err)
    return original(root, base, changes)
  end
  local it = check.must(store.load(s, id)); it.title = "snapshot B"
  local ok, err = write.save(s, it, "prepare snapshot B")
  projection.apply = original
  assert(ok and attempted, err)
  local b = check.must(workspace.read(s.root)).commit
  assert(b ~= a and not fs.is_present(workspace.recovery_path(s.root)),
    "a refused overlapping freeze leaves the completed composition mutable")
  local next_plan = check.must(publication.plan(s.root, b, "origin", nil))
  assert(check.must(publication.start(s.root, next_plan.plan)).local_commit == b,
    "the lock is released and publication freezes the exact new proposal")
  assert(recovery.clear(workspace.recovery_path(s.root)))
  assert(workspace.clear(s.root, b))
end

local function test_linked_worktree_processes_contend_on_one_kernel_lock()
  local s, _id = proposal("process-lock")
  local before = check.must(workspace.read(s.root)).commit
  local linked = fs.join(fixture.tmpdir, "snapshot-process-lock-linked")
  assert(fs.remove_all(linked))
  fixture.git(s.root, {"worktree", "add", "-q", "--detach", linked,
      "refs/heads/state"})
  assert(check.must(snapshot_lock.path(s.root)) == check.must(snapshot_lock.path(linked)))
  local ready = fs.join(fixture.tmpdir, "snapshot-lock-ready")
  local release = fs.join(fixture.tmpdir, "snapshot-lock-release")
  if fs.is_present(ready) then assert(fs.remove(ready)) end
  if fs.is_present(release) then assert(fs.remove(release)) end
  local script = ([[
    local fs = require("cosmic.fs")
    local time = require("cosmic.time")
    local lock = require("_work.snapshot_lock")
    local held = assert(lock.acquire(%q))
    assert(fs.write(%q, "ready\n"))
    while not fs.is_present(%q) do assert(time.sleep_ms(10)) end
    assert(held:close())
  ]]):format(linked, ready, release)
  local handle < close > = check.must(child.start({check.must(proc.interpreter()),
        "-e", script}))
  for _ = 1, 500 do
    if fs.is_present(ready) then break end
    check.must(time.sleep_ms(10))
  end
  assert(fs.is_present(ready), "child acquired the linked-worktree lock")
  local changed, err = workspace.resummary(s.root, "blocked resummary")
  assert(changed == nil and err:find("another snapshot", 1, true), err)
  assert(check.must(workspace.read(s.root)).commit == before)
  assert(fs.write(release, "release\n"))
  local result = check.must(handle:wait(10000))
  assert(result.ok, result.stderr)
  local after = check.must(workspace.resummary(s.root, "serialized resummary"))
  assert(after ~= before and fs.is_present(check.must(snapshot_lock.path(s.root))),
    "the persistent inode remains while kernel ownership was released")
  assert(workspace.clear(s.root, after))
end

local function test_phase_writes_cannot_race_abandon_or_confirmed_cleanup()
  local s, _id = proposal("phase-cleanup")
  local candidate = check.must(workspace.read(s.root))
  local planned = check.must(publication.plan(s.root, candidate.commit,
      "origin", nil))
  check.must(publication.start(s.root, planned.plan))
  check.must(publication.record_candidate(s.root, planned.plan,
      candidate.commit))
  local original_mark = recovery.mark_updating
  recovery.mark_updating = function(path: string, plan: snapshot.Plan,
      value: recovery.Recovery): recovery.Recovery | nil, string
    assert(gitboard.main("snapshot", "--abandon", candidate.commit,
        "--dir", s.root) == 1,
      "abandon fails fast while the updating phase owns serialization")
    return original_mark(path, plan, value)
  end
  local call, err = publication.update_call(s.root, candidate.commit, "origin",
    workspace.recovery_path(s.root), candidate.parent, nil)
  recovery.mark_updating = original_mark
  assert(call ~= nil, err)
  assert(check.must(recovery.load(workspace.recovery_path(s.root))).phase == "updating")
  assert(refs.update_ref(s.root, "refs/heads/state", candidate.commit,
      candidate.parent))
  local original_clear = recovery.clear
  recovery.clear = function(path: string): boolean, string
    local orphan, oerr = publication.record_candidate(s.root, planned.plan,
      candidate.commit)
    assert(orphan == nil and oerr:find("active in this process", 1, true), oerr)
    return original_clear(path)
  end
  local finished, detail = publication.execute(s.root, candidate.commit,
    "origin", nil)
  recovery.clear = original_clear
  assert(finished and detail:find("confirmed", 1, true), detail)
  local path = workspace.recovery_path(s.root)
  assert(not fs.is_present(path) and not fs.is_present(path .. ".candidate")
    and not fs.is_present(path .. ".updating"),
    "confirmed cleanup cannot leave a concurrently recreated sidecar")
end

local function test_cleaned_confirmation_is_recovered_after_claim_expiry()
  local s = fixture.init_state_repo("snapshot-cleaned-expired")
  local _, id = fixture.root_with_leaf(s)
  local now = os.time()
  local claimed = stateclaim.prepare(s.root, s.state_head,
    {{id = id, product_base = string.rep("a", 40)}}, "take", "holder",
    now, false, "")
  write.set_session(s, "holder")
  assert(statewrite.transition(s, claimed.changes, "claim by holder",
      claimed.publish_by))
  local commit = check.must(workspace.read(s.root)).commit
  assert(publication.execute(s.root, commit, "origin", now))
  assert(workspace.read(s.root) == nil
    and not fs.is_present(workspace.recovery_path(s.root)))
  local confirmed, detail = publication.execute(s.root, commit, "origin",
    now + 7200)
  assert(confirmed and detail:find("confirmed", 1, true), detail)
  assert(workspace.read(s.root) == nil
    and not fs.is_present(workspace.recovery_path(s.root)),
    "an exact fetched commit confirms without a new provider candidate")
end

local function test_discovery_refreshes_the_exact_configured_destination()
  local s = fixture.init_state_repo("snapshot-discovery-destination")
  local _, id = fixture.root_with_leaf(s)
  local it = check.must(store.load(s, id)); it.title = "destination candidate"
  write.set_session(s, "holder")
  assert(write.save(s, it, "destination candidate"))
  local candidate = check.must(workspace.read(s.root))
  local remote = fs.join(fixture.tmpdir, "snapshot-discovery-destination.git")
  assert(fs.remove_all(remote))
  fixture.git(fixture.tmpdir, {"init", "--bare", "-q", remote})
  fixture.git(s.root, {"remote", "add", "origin", remote})
  fixture.git(s.root, {"push", "-q", "origin",
      candidate.parent .. ":refs/heads/state",
      candidate.parent .. ":refs/heads/board/format",
      candidate.parent .. ":refs/heads/validation/recovery"})
  fixture.git(s.root, {"push", "-q", "origin",
      candidate.commit .. ":refs/heads/state"})
  fixture.git(s.root, {"fetch", "-q", "origin",
      "+refs/heads/state:refs/remotes/origin/state",
      "+refs/heads/board/format:refs/remotes/origin/board/format"})
  assert(refs.set_board_mode(s.root, "remote"))
  fixture.git(s.root, {"config", "gitboard.publicationBranch",
      "validation/recovery"})
  local planned = check.must(publication.plan(s.root, candidate.commit,
      "origin", nil))
  local state = check.must(publication.start(s.root, planned.plan))
  assert(state.phase == "prepared",
    "a match cached from state is not proof for validation/recovery")
  assert(check.must(refs.read_ref(s.root, "refs/remotes/origin/state"))
    == candidate.parent, "discovery fetched the exact configured branch")
  assert(recovery.clear(workspace.recovery_path(s.root)))
  assert(refs.update_ref(s.root, "refs/remotes/origin/state",
      candidate.commit, candidate.parent))
  assert(fs.remove_all(remote))
  local refused, err = publication.start(s.root, planned.plan)
  assert(refused == nil
    and err:find("uncertain: cannot inspect exact publication destination:",
      1, true) == 1, err)
  assert(not fs.is_present(workspace.recovery_path(s.root)),
    "an unreadable selected destination is not frozen as a new attempt")
  assert(workspace.clear(s.root, candidate.commit))
end
