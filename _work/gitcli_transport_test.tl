#!/usr/bin/env cosmic
-- CLI contract at the native state publication boundary: durable render-only
-- preparation, explicit execution, configured remotes, drafts and sessions.
local boardread = require("_work.boardread")
local check = require("cosmic.check")
local claimsession = require("_work.claimsession")
local fixture = require("_work.fixture")
local fs = require("cosmic.fs")
local gitboard = require("_work.gitboard")
local gitdraft = require("_work.gitdraft")
local refs = require("_work.refs")
local staging = require("_work.statestaging")
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
  local pending = check.must(staging.list(root, "prepared"))
  assert(#pending == 1 and pending[1].remote == "upstream")
  assert(out:find(pending[1].id, 1, true), out)
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
  local pending = check.must(staging.list(root, "prepared"))
  assert(#pending == 1 and #pending[1].transitions == 1)
  assert(out:find("NOT PUBLISHED", 1, true), out)
  assert(out:find("gitboard publish " .. pending[1].id .. " --execute",
      1, true), out)
end

local function test_draft_cli_stages_offline_and_plans_one_state_update()
  local s = fixture.init_state_repo("cli-draft-overlay")
  local id = fixture.file_item(s, "before draft", "")
  local root, canonical = s.root, s.state_head
  assert(store.close(s))
  local draft = check.must(gitdraft.begin(root))
  local code, out = capture("set", id, "--title", "inside draft",
    "--draft", draft.id, "--dir", root)
  assert(code == 0 and out:find("STAGED draft=", 1, true), out)
  local reopened = check.must(gitdraft.open(root, draft.id))
  local plan = gitdraft.plan(reopened)
  assert(#plan == 1 and plan[1].ref == "refs/heads/state")
  assert(plan[1].expected == canonical and plan[1].next == reopened.native.tip)
  assert(gitdraft.activate(root, reopened))
  local speculative = check.must(store.open(root))
  assert(check.must(store.load(speculative, id)).title == "inside draft")
  assert(store.close(speculative))
  gitdraft.deactivate(root)
  local current = check.must(store.open(root))
  assert(check.must(store.load(current, id)).title == "before draft")
  assert(store.close(current))
end

local function test_local_draft_applies_only_on_explicit_publish()
  local s = fixture.init_state_repo("cli-draft-local")
  local id = fixture.file_item(s, "local before", "")
  local root = s.root
  assert(store.close(s))
  local draft = check.must(gitdraft.begin(root))
  local code, out = capture("set", id, "--title", "local after",
    "--draft", draft.id, "--dir", root)
  assert(code == 0 and out:find("STAGED draft=", 1, true), out)
  gitdraft.deactivate(root)
  local current = check.must(store.open(root))
  assert(check.must(store.load(current, id)).title == "local before")
  assert(store.close(current))
  code, out = capture("publish", draft.id, "--execute", "--dir", root)
  assert(code == 0, out)
  current = check.must(store.open(root))
  assert(check.must(store.load(current, id)).title == "local after")
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
  local pending = check.must(staging.list(root, "prepared"))
  assert(#pending == 1)
  local publish_code, publish_out = capture("publish", pending[1].id,
    "--dir", root)
  assert(publish_code == 0, publish_out)
  assert(publish_out:find(pending[1].id, 1, true), publish_out)
  assert(publish_out:find("publication ready", 1, true), publish_out)
  assert(publish_out:find("--plan FILE", 1, true), publish_out)
  assert(check.must(refs.read_ref(root, pending[1].ref)) == pending[1].sha)
end
print("gitcli_transport_test: ok")
