#!/usr/bin/env cosmic
--- Public regressions for snapshot publication concurrency and recovery.
local boardtree = require("_work.boardtree")
local boardread = require("_work.boardread")
local check = require("cosmic.check")
local claim = require("_work.claim")
local claimsession = require("_work.claimsession")
local env = require("cosmic.env")
local fixture = require("_work.fixture")
local flow = require("_work.commit_flow_fixture")
local fs = require("cosmic.fs")
local git = require("_work.singlehead_git")
local gitboard = require("_work.gitboard")
local publication = require("_work.snapshot_publish")
local recovery = require("_work.snapshot_recovery")
local refs = require("_work.refs")
local snapshot = require("_work.snapshot")
local stateclaim = require("_work.stateclaim")
local statewrite = require("_work.statewrite")
local store = require("_work.store")
local write = require("_work.storewrite")
local workspace = require("_work.snapshot_workspace")

local function capture(...: string): integer, string
  local old = _G.print
  local lines: {string} = {}
  _G.print = function(...: any)
    local parts: {string} = {}
    for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
    lines[#lines + 1] = table.concat(parts, "\t")
  end
  local ok, code = pcall(gitboard.main, ...)
  _G.print = old
  if not ok then error(code, 0) end
  return code, table.concat(lines, "\n")
end

local function title_exists(root: string, title: string): boolean
  local s = check.must(store.open(root))
  for _, it in ipairs(check.must(store.list(s))) do
    if it.title == title then return true end
  end
  return false
end

local function test_public_cli_refuses_stale_composition_after_refresh()
  local a, b = fixture.init_shared("feedback-stale-composition")
  local one, two = claimsession.mint(), claimsession.mint()
  assert(capture("new", "A", "--session", one, "--dir", a.root) == 0)
  local stale = check.must(workspace.read(a.root))
  assert(capture("new", "B", "--session", two, "--dir", b.root) == 0)
  local winner = check.must(workspace.read(b.root))
  assert(capture("publish", winner.commit, "--dir", b.root) == 0)
  assert(capture("refresh", "--execute", "--dir", a.root) == 0)
  local code, out = capture("new", "A2", "--session", one, "--dir", a.root)
  assert(code ~= 0 and out:find("snapshot --abandon " .. stale.commit, 1, true), out)
  refs.clear_overlay(a.root)
  assert(title_exists(a.root, "B") and not title_exists(a.root, "A2"),
    "the canonical winner survives the stale composition refusal")
end

local function test_same_session_guidance_and_frozen_summary_cli()
  local a, _b = fixture.init_shared("feedback-session-summary")
  local owner = claimsession.mint()
  assert(capture("new", "owned", "--session", owner, "--dir", a.root) == 0)
  local candidate = check.must(workspace.read(a.root))
  local code, out = capture("new", "wrong session", "--session",
    claimsession.mint(), "--dir", a.root)
  assert(code ~= 0 and out:find("--session", 1, true)
    and out:find("GITBOARD_SESSION", 1, true), out)
  local planned = check.must(publication.plan(a.root, candidate.commit, "origin", nil))
  assert(recovery.begin(workspace.recovery_path(a.root), planned.plan))
  code, out = capture("snapshot", "--summary", "changed", "--dir", a.root)
  assert(code ~= 0 and out:find("immutable", 1, true), out)
  assert(recovery.clear(workspace.recovery_path(a.root)))
end

local function test_draft_selectors_are_explicitly_refused()
  local s = fixture.init_state_repo("feedback-draft-cli")
  assert(capture("draft", "named", "--dir", s.root) ~= 0)
  assert(capture("show", "--draft", "named", "--dir", s.root) ~= 0)
  assert(env.set("GITBOARD_DRAFT", "named"))
  local code, out = capture("show", "--dir", s.root)
  assert(env.unset("GITBOARD_DRAFT"))
  assert(code ~= 0 and out:find("GITBOARD_DRAFT", 1, true), out)
end

local function install_hook(root: string, body: string): string
  local common = check.must(require("_work.snapshot_lock").common_dir(root))
  local path = fs.join(common, "hooks/pre-push")
  assert(fs.write(path, "#!/bin/sh\n" .. body, {mode = 493}))
  return path
end

local function test_updating_is_durable_before_shell_push()
  local a, _b = fixture.init_shared("feedback-shell-arm")
  assert(capture("new", "arm before push", "--session", claimsession.mint(),
      "--dir", a.root) == 0)
  local candidate = check.must(workspace.read(a.root))
  local path = workspace.recovery_path(a.root)
  local marker = fs.join(fixture.tmpdir, "feedback-shell-arm-seen")
  if fs.is_present(marker) then assert(fs.remove(marker)) end
  install_hook(a.root, ("test -f %q || { echo missing-updating >&2; exit 1; }\n"
      .. "printf seen > %q\n"):format(path .. ".updating", marker))
  local code, out = capture("publish", candidate.commit, "--dir", a.root)
  assert(code == 0 and fs.is_present(marker), out)
  assert(check.must(refs.read_ref(a.root, "refs/remotes/origin/state"))
    == candidate.commit)
end

local function test_leased_push_refuses_a_remote_rewind()
  local a, _b = fixture.init_shared("feedback-shell-rewind")
  fixture.file_item(a, "published ancestor", "")
  assert(capture("new", "rewind candidate", "--session", claimsession.mint(),
      "--dir", a.root) == 0)
  local candidate = check.must(workspace.read(a.root))
  local ancestor = check.must(git.text(a.root,
      {"rev-parse", candidate.parent .. "^"}))
  local bare = check.must(git.text(a.root,
      {"remote", "get-url", "--push", "origin"}))
  local original = refs.push_atomic
  refs.push_atomic = function(root: string, specs: {refs.PushSpec},
      destination?: string): boolean, boolean, string
    assert(git.text(a.root, {"--git-dir=" .. bare, "update-ref",
          "refs/heads/state", ancestor, candidate.parent}))
    return original(root, specs, destination)
  end
  local code = capture("publish", candidate.commit, "--dir", a.root)
  refs.push_atomic = original
  assert(code ~= 0, "the exact lease must reject a concurrent rewind")
  local remote = check.must(git.text(a.root,
      {"ls-remote", "--refs", bare, "refs/heads/state"})):match("^([0-9a-f]+)")
  assert(remote == ancestor, "the publication must not overwrite the rewind")
end

local function provider_commit(root: string, plan: snapshot.Plan): string
  return check.must(git.text(root,
      {"commit-tree", plan.tree, "-p", plan.parent}, plan.message, {
        GIT_AUTHOR_NAME = "Provider", GIT_AUTHOR_EMAIL = "provider@example.test",
        GIT_AUTHOR_DATE = plan.author.date, GIT_COMMITTER_NAME = "Provider",
        GIT_COMMITTER_EMAIL = "provider@example.test",
        GIT_COMMITTER_DATE = plan.author.date}))
end

local function test_shell_resume_pushes_only_the_saved_provider_candidate()
  local a, _b = fixture.init_shared("feedback-saved-provider")
  assert(capture("new", "provider candidate", "--session", claimsession.mint(),
      "--dir", a.root) == 0)
  local candidate = check.must(workspace.read(a.root))
  local planned = check.must(publication.plan(a.root, candidate.commit, "origin", nil))
  assert(publication.start(a.root, planned.plan))
  local remote_sha = provider_commit(a.root, planned.plan)
  assert(remote_sha ~= candidate.commit)
  assert(publication.record_candidate(a.root, planned.plan, remote_sha))
  local ok, detail = publication.execute(a.root, candidate.commit, "origin", nil)
  assert(ok, detail)
  assert(check.must(refs.read_ref(a.root, "refs/remotes/origin/state")) == remote_sha,
    "shell recovery publishes the durable provider SHA, never the local substitute")
end

local function test_destination_and_mode_changes_refuse_resume()
  local a, _b = fixture.init_shared("feedback-destination-binding")
  assert(capture("new", "bound destination", "--session", claimsession.mint(),
      "--dir", a.root) == 0)
  local candidate = check.must(workspace.read(a.root))
  local planned = check.must(publication.plan(a.root, candidate.commit, "origin", nil))
  assert(recovery.begin(workspace.recovery_path(a.root), planned.plan))
  local local_before = check.must(refs.read_ref(a.root, "refs/heads/state"))
  assert(refs.set_board_mode(a.root, "local"))
  local ok, err = publication.execute(a.root, candidate.commit, "origin", nil)
  assert(not ok and err:find("destination", 1, true), err)
  assert(check.must(refs.read_ref(a.root, "refs/heads/state")) == local_before)
  assert(refs.set_board_mode(a.root, "remote"))
  assert(recovery.clear(workspace.recovery_path(a.root)))
  assert(workspace.clear(a.root, candidate.commit))
end

local function test_remote_endpoint_change_refuses_resume()
  local a, _b = fixture.init_shared("feedback-endpoint-binding")
  assert(capture("new", "endpoint binding", "--session", claimsession.mint(),
      "--dir", a.root) == 0)
  local candidate = check.must(workspace.read(a.root))
  local planned = check.must(publication.plan(a.root, candidate.commit, "origin", nil))
  assert(recovery.begin(workspace.recovery_path(a.root), planned.plan))
  local other = fs.join(fixture.tmpdir, "feedback-other-destination.git")
  assert(fs.remove_all(other) and git.run(a.root, {"init", "--bare", "-q", other}))
  assert(git.run(a.root, {"remote", "set-url", "--push", "origin", other}))
  local ok, err = publication.execute(a.root, candidate.commit, "origin", nil)
  assert(not ok and err:find("destination", 1, true), err)
  local original = check.must(git.text(a.root, {"ls-remote", "--refs",
        planned.plan.destination.target_url, "refs/heads/state"})):match("^([0-9a-f]+)")
  assert(original == candidate.parent)
  assert(check.must(git.text(a.root,
        {"ls-remote", "--refs", other, "refs/heads/state"})) == "")
end

local function reauthor(root: string, commit: string, epoch: integer): string
  local identity = check.must(snapshot.commit_identity(root, commit))
  identity.author.date = tostring(epoch) .. " +0000"
  local message = check.must(snapshot.message("historically valid", identity.author))
  return check.must(git.text(root, {"commit-tree", identity.tree, "-p", identity.parent},
      message, {GIT_AUTHOR_NAME = identity.author.name,
        GIT_AUTHOR_EMAIL = identity.author.email, GIT_AUTHOR_DATE = identity.author.date,
        GIT_COMMITTER_NAME = "gitboard", GIT_COMMITTER_EMAIL = "gitboard@localhost",
        GIT_COMMITTER_DATE = identity.author.date}))
end

local function test_resume_rechecks_clock_sensitive_authority()
  local s = fixture.init_state_repo("feedback-live-authority")
  local _, id = fixture.root_with_leaf(s)
  local expires = os.time() + 120
  local lease_record: boardtree.Claim = {id = boardtree.mint_claim_id(), holder = "foreign",
    acquired_at = expires - 7200, renewed_at = expires - 7200,
    expires_at = expires, product_base = s.state_head}
  fixture.raw_seed_claim(s, id, lease_record, "foreign claim")
  local it = check.must(store.load(s, id)); it.title = "historically allowed"
  write.set_session(s, "other")
  assert(write.save(s, it, "historically allowed"))
  local ordinary = check.must(workspace.read(s.root)).commit
  local commit = reauthor(s.root, ordinary, expires + 1)
  assert(workspace.clear(s.root, ordinary) and workspace.retain(s.root, commit))
  local planned = check.must(publication.plan(s.root, commit, "origin", expires + 1))
  assert(recovery.begin(workspace.recovery_path(s.root), planned.plan))
  local before = check.must(refs.read_ref(s.root, "refs/heads/state"))
  local ok, err = publication.execute(s.root, commit, "origin", expires - 1)
  assert(not ok and err:find("foreign until", 1, true), err)
  assert(check.must(refs.read_ref(s.root, "refs/heads/state")) == before)
end

local function test_resume_rechecks_clock_validity_after_rollback()
  local s, id, product = flow.fresh("feedback-live-clock")
  assert(flow.claim(s, id, flow.BUILDER, product) == 0)
  local renewed = check.must(boardread.list(s.root,
      s.state_head)).claims_by_id[id].renewed_at + 1
  local result = stateclaim.prepare(s.root, s.state_head,
    {{id = id, product_base = product.base}}, "renew", flow.BUILDER,
    renewed, false, "")
  write.set_session(s, flow.BUILDER)
  assert(statewrite.transition(s, result.changes, "renew by holder", result.publish_by))
  local commit = check.must(workspace.read(s.root)).commit
  local authored = check.must(snapshot.author_time(
      check.must(snapshot.commit_identity(s.root, commit)).author))
  local planned = check.must(publication.plan(s.root, commit, "origin", authored))
  assert(recovery.begin(workspace.recovery_path(s.root), planned.plan))
  local before = check.must(refs.read_ref(s.root, "refs/heads/state"))
  local ok, err = publication.execute(s.root, commit, "origin",
    authored - claim.FUTURE_SKEW_S - 1)
  assert(not ok and err:find("future", 1, true), err)
  assert(check.must(refs.read_ref(s.root, "refs/heads/state")) == before)
end

local function test_orphan_recovery_reads_and_safe_abandon()
  local a, _b = fixture.init_shared("feedback-orphan-abandon")
  assert(capture("new", "orphan recovery", "--session", claimsession.mint(),
      "--dir", a.root) == 0)
  local candidate = check.must(workspace.read(a.root))
  local planned = check.must(publication.plan(a.root, candidate.commit, "origin", nil))
  local path = workspace.recovery_path(a.root)
  assert(recovery.begin(path, planned.plan))
  assert(publication.record_candidate(a.root, planned.plan, candidate.commit))
  assert(require("_work.snapshot_protocol").arm_update(path, planned.plan,
      check.must(recovery.load(path)), candidate.parent, nil))
  assert(workspace.clear(a.root, candidate.commit))
  assert(fs.remove(path) and fs.remove(path .. ".candidate"))
  assert(capture("show", "--dir", a.root) == 0,
    "canonical reads ignore orphan recovery parsing")
  local code, out = capture("snapshot", "--abandon", candidate.commit,
    "--dir", a.root)
  assert(code ~= 0 and out:find("uncertain", 1, true), out)
  assert(fs.is_present(path .. ".updating"), "uncertain orphan is retained")
end

local function test_record_only_candidate_can_be_safely_abandoned()
  local a, _b = fixture.init_shared("feedback-record-only-abandon")
  assert(capture("new", "record only", "--session", claimsession.mint(),
      "--dir", a.root) == 0)
  local candidate = check.must(workspace.read(a.root))
  local planned = check.must(publication.plan(a.root, candidate.commit, "origin", nil))
  local path = workspace.recovery_path(a.root)
  assert(recovery.begin(path, planned.plan))
  assert(publication.record_candidate(a.root, planned.plan, candidate.commit))
  assert(workspace.clear(a.root, candidate.commit))
  assert(capture("show", "--dir", a.root) == 0)
  local code, out = capture("snapshot", "--abandon", candidate.commit,
    "--dir", a.root)
  assert(code == 0, out)
  assert(check.must(refs.read_ref(a.root,
        "refs/gitboard/conflicts/" .. candidate.commit)) == candidate.commit)
  assert(not recovery.present(path))
end

local function test_malformed_recovery_never_blocks_reads_or_gets_deleted()
  local a, _b = fixture.init_shared("feedback-malformed-read")
  assert(capture("new", "malformed recovery", "--session", claimsession.mint(),
      "--dir", a.root) == 0)
  local candidate = check.must(workspace.read(a.root))
  local path = workspace.recovery_path(a.root)
  assert(fs.write(path, "not a literal\n"))
  assert(capture("show", "--dir", a.root) == 0)
  assert(capture("new", "blocked write", "--dir", a.root) ~= 0)
  local code, out = capture("snapshot", "--abandon", candidate.commit,
    "--dir", a.root)
  assert(code ~= 0 and out:find("malformed recovery", 1, true), out)
  assert(fs.is_present(path), "malformed recovery is never blindly deleted")
end

local function test_known_start_conflict_does_not_freeze()
  local a, b = fixture.init_shared("feedback-known-start-conflict")
  assert(capture("new", "loser", "--session", claimsession.mint(),
      "--dir", a.root) == 0)
  local loser = check.must(workspace.read(a.root))
  local planned = check.must(publication.plan(a.root, loser.commit, "origin", nil))
  assert(capture("new", "winner", "--session", claimsession.mint(),
      "--dir", b.root) == 0)
  local winner = check.must(workspace.read(b.root))
  assert(capture("publish", winner.commit, "--dir", b.root) == 0)
  local state, err = publication.start(a.root, planned.plan)
  assert(state == nil and err:find("conflict", 1, true), err)
  assert(not recovery.present(workspace.recovery_path(a.root)),
    "a known conflict is retained for abandonment without freezing publication")
  assert(check.must(workspace.read(a.root)).commit == loser.commit)
end

local function test_composition_requires_the_canonical_start()
  local s = fixture.init_state_repo("feedback-canonical-start")
  local parent = check.must(workspace.canonical_head(s.root))
  local wrong = parent:sub(1, 39) .. (parent:sub(40) == "0" and "1" or "0")
  local tip, err = workspace.compose(s.root, parent, wrong, "session", {}, "wrong")
  assert(tip == nil and err:find("did not start at canonical", 1, true), err)
end
