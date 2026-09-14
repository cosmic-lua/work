#!/usr/bin/env cosmic
-- CLI contract at the native snapshot publication boundary: local composition,
-- explicit publication, configured remotes, and sessions.
local boardread = require("_work.boardread")
local check = require("cosmic.check")
local claimsession = require("_work.claimsession")
local fixture = require("_work.fixture")
local fs = require("cosmic.fs")
local gitboard = require("_work.gitboard")
local refs = require("_work.refs")
local snapshot_publish = require("_work.snapshot_publish")
local workspace = require("_work.snapshot_workspace")
local store = require("_work.store")

local function capture(...: string): integer, string
  local old_print = _G.print
  local lines: {string} = {}
  _G.print = function(...: any)
    local parts: {string} = {}
    for i = 1, select("#", ...) do
      parts[i] = tostring((select(i, ...)))
    end
    lines[#lines + 1] = table.concat(parts, "\t")
  end
  local ok, code = pcall(gitboard.main, ...)
  _G.print = old_print
  if not ok then error(code, 0) end
  return code, table.concat(lines, "\n")
end

local function test_claim_uses_the_configured_non_origin_remote()
  local writer, s = fixture.init_shared("cli-claim-upstream")
  local id = fixture.file_item(writer, "claim from upstream", "")
  fixture.caller_fetch(s)
  fixture.git(s.root, {"remote", "rename", "origin", "upstream"})
  assert(refs.set_board_remote(s.root, "upstream"))
  local root = s.root
  assert(store.close(s))
  local code, out = capture("claim", id, "--session", claimsession.mint(),
    "--remote", "upstream", "--dir", root)
  assert(code == 2, out)
  local candidate = check.must(workspace.read(root))
  local planned = check.must(snapshot_publish.plan(root, candidate.commit,
      "upstream", nil))
  assert(planned.plan.destination.remote == "upstream")
  assert(out:find(candidate.commit, 1, true), out)
end

local function test_claim_set_prepares_one_atomic_state_transition()
  local writer, s = fixture.init_shared("cli-claim-set")
  local first = fixture.file_item(writer, "first atomic claim", "")
  local second = fixture.file_item(writer, "second atomic claim", "")
  fixture.caller_fetch(s)
  local root = s.root
  assert(store.close(s))
  local code, out = capture("claim", first, second, "--session",
    claimsession.mint(), "--dir", root)
  assert(code == 2, out)
  local candidate = check.must(workspace.read(root))
  local planned = check.must(snapshot_publish.plan(root, candidate.commit,
      refs.board_remote(root), nil))
  assert(#planned.report.changed == 2, "one snapshot contains the whole claim set")
  assert(out:find("gitboard publish " .. candidate.commit, 1, true), out)
end

local function test_session_new_prints_only_a_minted_identity()
  local code, out = capture("session", "new")
  assert(code == 0 and claimsession.is_id(out), out)
  local help_code, help = capture("help", "session")
  assert(help_code == 0 and help:find("does not derive identity", 1, true),
    help)
end

local function test_init_records_explicit_mode()
  local root = fs.join(fixture.tmpdir, "verbs-cli-explicit-init")
  assert(fs.remove_all(root) and fs.make_dirs(root))
  local code, out = capture("init", "--local", "--dir", root)
  assert(code == 0 and refs.board_mode(root) == "local", out)
  local refused = capture("init", "--local", "--remote", "--dir", root)
  assert(refused ~= 0)
end

local function test_refresh_fetches_only_when_execution_is_explicit()
  local writer, s = fixture.init_shared("cli-refresh-render")
  local before = check.must(refs.read_ref(s.root, "refs/remotes/origin/state"))
  fixture.file_item(writer, "remote advance", "")
  local remote = check.must(store.git_ok(s,
      {"ls-remote", "origin", "refs/heads/state"})).stdout:match("^(%x+)")
  assert(remote ~= nil and remote ~= before)
  local root = s.root
  assert(store.close(s))
  local code, out = capture("refresh", "--dir", root)
  assert(code == 0, out)
  assert(check.must(refs.read_ref(root, "refs/remotes/origin/state")) == before,
    "default refresh must inspect only what the caller already fetched")
  code, out = capture("refresh", "--execute", "--dir", root)
  assert(code == 0, out)
  assert(check.must(refs.read_ref(root, "refs/remotes/origin/state")) == remote)
end

local function test_local_claim_writes_canonical_claim_authority()
  local s = fixture.init_state_repo("cli-claim-local")
  local id = fixture.file_item(s, "claim any existing item", "")
  local caller, root = claimsession.mint(), s.root
  assert(store.close(s))
  local code, out = capture("claim", id, "--session", caller, "--dir", root)
  assert(code == 0, out)
  local current = check.must(store.open(root))
  local value = check.must(check.must(boardread.load(root,
        current.state_head, id)).claim)
  assert(value.holder == caller)
end

local function test_publish_rediscovers_a_rendered_native_claim()
  local writer, s = fixture.init_shared("cli-claim-publish")
  local id = fixture.file_item(writer, "publish an offline claim", "")
  fixture.caller_fetch(s)
  local root = s.root
  assert(store.close(s))
  local claim_code, claim_out = capture("claim", id, "--session",
    claimsession.mint(), "--dir", root)
  assert(claim_code == 2, claim_out)
  local pending = check.must(workspace.read(root))
  local publish_code, publish_out = capture("publish", pending.commit,
    "--dir", root)
  assert(publish_code == 0, publish_out)
  assert(publish_out:find(pending.commit, 1, true), publish_out)
  assert(publish_out:find("confirmed", 1, true), publish_out)
  assert(check.must(refs.read_ref(root, "refs/remotes/origin/state"))
    == pending.commit)
  assert(workspace.read(root) == nil, "confirmed publication clears the proposal")
end
print("gitcli_transport_test: ok")
