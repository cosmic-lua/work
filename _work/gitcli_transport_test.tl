#!/usr/bin/env cosmic
-- Focused CLI contract for the credential-free transport seam: session ids,
-- render-only defaults, explicit execution wording, and local claim wiring.
local check = require("cosmic.check")
local claimsession = require("_work.claimsession")
local fixture = require("_work.fixture")
local fs = require("cosmic.fs")
local gitboard = require("_work.gitboard")
local gitclaim = require("_work.gitclaim")
local gitobj = require("_work.gitobj")
local prepared = require("_work.prepared")
local refs = require("_work.refs")
local store = require("_work.store")

local function capture(...: string): integer, string
  local old_print = _G.print
  local lines: {string} = {}
  _G.print = function(...: any)
    local parts: {string} = {}
    for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
    lines[#lines + 1] = table.concat(parts, "\t")
  end
  local ok, code = pcall(gitboard.main, ...)
  _G.print = old_print
  if not ok then error(code, 0) end
  return code, table.concat(lines, "\n")
end

local function mirror_board(root: string, remote?: string)
  local found = check.must(refs.for_each_ref_raw(root,
      {"refs/heads/items", "refs/heads/ended", "refs/heads/board"}))
  for _, entry in ipairs(found) do
    local tracked = check.must(refs.tracking_ref(entry.refname, remote))
    assert(refs.update_ref(root, tracked, entry.sha, refs.ZERO_SHA))
  end
end

local function test_claim_uses_an_explicit_non_origin_canonical_remote()
  local s = fixture.init_state_repo("cli-claim-upstream")
  local id = fixture.file_item(s, "claim from upstream tracking", "")
  mirror_board(s.root, "upstream")
  assert(refs.set_board_mode(s.root, "remote"))
  local caller = claimsession.mint()
  local root = s.root
  local _closed, _cerr = store.close(s)
  local code, out = capture("claim", id, "--session", caller,
    "--remote", "upstream", "--dir", root)
  assert(code == 2, out)
  assert(out:find(" upstream ", 1, true), out)
  assert(out:find("refs/remotes/origin", 1, true) == nil, out)
end
test_claim_uses_an_explicit_non_origin_canonical_remote()

local function successor(root: string, parent: string): string
  local tree = check.must(gitobj.tree_of(root, parent))
  return check.must(gitobj.commit_tree(root, {
        tree = tree, parents = {parent}, message = "CLI prepared successor",
        author_name = "test", author_email = "test@example.com",
        committer_name = "test", committer_email = "test@example.com",
      }))
end

local function test_session_new_prints_only_a_minted_identity()
  local code, out = capture("session", "new")
  assert(code == 0 and claimsession.is_id(out), out)
  local help_code, help = capture("help", "session")
  assert(help_code == 0 and help:find("does not derive identity", 1, true), help)
end
test_session_new_prints_only_a_minted_identity()

local function test_help_exposes_only_commit_and_caller_owned_remote_contracts()
  local _, take = capture("help", "take")
  assert(take:find("--head", 1, true) and take:find("--repo-dir", 1, true), take)
  assert(not take:find("--pr", 1, true) and not take:find("--open", 1, true),
    take)
  local _, verdict = capture("help", "verdict")
  assert(verdict:find("only evidence", 1, true), verdict)
  assert(not verdict:find("GitHub", 1, true)
    and not verdict:find("--no-land", 1, true), verdict)
  local _, done = capture("help", "done")
  assert(done:find("--landed", 1, true) and done:find("--session", 1, true), done)
end
test_help_exposes_only_commit_and_caller_owned_remote_contracts()

local function test_init_records_explicit_mode_and_migrate_dispatches_pre_open()
  local root = fs.join(fixture.tmpdir, "verbs-cli-explicit-init")
  assert(fs.remove_all(root))
  assert(fs.make_dirs(root))
  local code, out = capture("init", "--local", "--dir", root)
  assert(code == 0 and refs.board_mode(root) == "local", out)
  local migrate_code, migrate_out = capture("migrate", "--dir", root)
  assert(migrate_code == 0
    and migrate_out:find("already current", 1, true), migrate_out)
  local refused = capture("init", "--local", "--remote", "--dir", root)
  assert(refused ~= 0, "init must reject contradictory board modes")
end
test_init_records_explicit_mode_and_migrate_dispatches_pre_open()

local function test_refspec_setup_uses_the_configured_remote_name()
  local base = fs.join(fixture.tmpdir, "configured-refspec")
  assert(fs.remove_all(base))
  assert(fs.make_dirs(base))
  local bare = fs.join(base, "board.git")
  local root = fs.join(base, "checkout")
  fixture.git(base, {"init", "-q", "--bare", bare})
  fixture.git(base, {"init", "-q", root})
  fixture.git(root, {"remote", "add", "upstream", bare})
  assert(refs.set_board_remote(root, "upstream"))
  assert(refs.ensure_refspecs(root))
  local config = check.must(fs.read(fs.join(root, ".git", "config")))
  assert(config:find("refs/remotes/upstream/items/", 1, true), config)
  assert(config:find("refs/remotes/origin/items/", 1, true) == nil, config)
end
test_refspec_setup_uses_the_configured_remote_name()

local function test_publish_defaults_to_an_exact_render_without_moving_refs()
  local s = fixture.init_state_repo("cli-publish-render")
  local id = fixture.file_item(s, "publish target", "")
  local target = "refs/heads/items/" .. id
  local old = check.must(refs.read_ref(s.root, target))
  local next_sha = successor(s.root, old)
  local tx = check.must(prepared.prepare(s.root, {
        {ref = target, expected = old, next = next_sha},
      }))
  assert(refs.set_board_mode(s.root, "remote"))
  local _closed, _cerr = store.close(s)
  local code, out = capture("publish", tx.id, "--dir", s.root)
  assert(code == 0, out)
  assert(out:find("git push --atomic", 1, true), out)
  assert(out:find("--force-with-lease=" .. target .. ":" .. old, 1, true), out)
  assert(out:find(next_sha .. ":" .. target, 1, true), out)
  assert(out:find("nothing executed", 1, true), out)
  assert(check.must(refs.read_ref(s.root, target)) == old,
    "rendering publication cannot move canonical refs")
end
test_publish_defaults_to_an_exact_render_without_moving_refs()

local function test_refresh_defaults_to_rendered_fetch_and_local_reconciliation()
  local s = fixture.init_state_repo("cli-refresh-render")
  mirror_board(s.root)
  assert(refs.set_board_mode(s.root, "remote"))
  local _closed, _cerr = store.close(s)
  local code, out = capture("refresh", "--dir", s.root)
  assert(code == 0, out)
  assert(out:find("git fetch --prune origin", 1, true), out)
  assert(out:find("refs/remotes/origin/items/", 1, true), out)
  assert(out:find("fetched refs were not changed", 1, true), out)
end
test_refresh_defaults_to_rendered_fetch_and_local_reconciliation()

local function test_local_claim_dispatches_to_the_new_claim_substrate()
  local s = fixture.init_state_repo("cli-claim-local")
  local id = fixture.file_item(s, "claim any existing item", "")
  local caller = claimsession.mint()
  local root = s.root
  local _closed, _cerr = store.close(s)
  local code, out = capture("claim", id, "--session", caller, "--dir", root)
  assert(code == 0, out)
  assert(out:find("confirmed " .. id, 1, true), out)
  local reopened = check.must(store.open(root))
  local claimed = check.must(store.load(reopened, id))
  assert(claimed.claim == caller, "claim command must record the minted caller")
end
test_local_claim_dispatches_to_the_new_claim_substrate()

local function test_publish_rediscovers_rendered_claim_transactions()
  local s = fixture.init_state_repo("cli-claim-publish")
  local id = fixture.file_item(s, "publish an offline claim", "")
  mirror_board(s.root)
  assert(refs.set_board_mode(s.root, "remote"))
  local caller = claimsession.mint()
  local root = s.root
  local _closed, _cerr = store.close(s)
  local claim_code, claim_out = capture("claim", id, "--session", caller,
    "--dir", root)
  assert(claim_code == 2, claim_out)
  assert(claim_out:find("git push --force-with-lease=", 1, true), claim_out)
  assert(claim_out:find("PREPARED", 1, true)
    and claim_out:find("No claim was acquired", 1, true), claim_out)
  assert(claim_out:find("do not act", 1, true), claim_out)
  local staged = check.must(gitclaim.list_prepared(root, "origin"))
  assert(#staged == 1 and staged[1].id == id,
    "render-only claim must remain staging-reachable")
  local retry_code, retry_out = capture("claim", id, "--session", caller,
    "--dir", root)
  assert(retry_code == 2, retry_out)
  local retried = check.must(gitclaim.list_prepared(root, "origin"))
  assert(#retried == 1 and retried[1].new_sha == staged[1].new_sha,
    "retrying a rendered claim must reuse its Git-native CAS")
  assert(retry_out:find(staged[1].staging_ref .. ":"
      .. staged[1].target_ref, 1, true), retry_out)
  local publish_code, publish_out = capture("publish", "--dir", root)
  assert(publish_code == 0, publish_out)
  assert(publish_out:find(staged[1].staging_ref .. ":"
      .. staged[1].target_ref, 1, true), publish_out)
  assert(publish_out:find("nothing executed", 1, true), publish_out)

  -- A caller may run the printed push and fetch itself.  Refresh only
  -- reconciles those already-fetched refs, then removes the staging receipt.
  local tracked = check.must(refs.tracking_ref(staged[1].target_ref))
  assert(refs.update_ref(root, tracked, staged[1].new_sha, staged[1].old_sha))
  local refresh_code, refresh_out = capture("refresh", "--dir", root)
  assert(refresh_code == 0, refresh_out)
  assert(refresh_out:find("confirmed " .. staged[1].new_sha, 1, true),
    refresh_out)
  assert(#check.must(gitclaim.list_prepared(root, "origin")) == 0,
    "confirmed claim staging ref must be cleaned")
end
test_publish_rediscovers_rendered_claim_transactions()
print("gitcli_transport_test: ok")
