#!/usr/bin/env cosmic
-- Adoption's live-authority checks and unsupported targets. Success paths
-- and final post-build checks are in `_work/worktree_adopt_test.tl`;
-- checkout refusal, manual/review, real-alias, and submodule cases remain in
-- `_work/worktree_adopt_refusal_test.tl`.
local check = require("cosmic.check")
local child = require("cosmic.child")
local env = require("cosmic.env")
local fs = require("cosmic.fs")
local hash = require("cosmic.hash")
local claim = require("_work.claim")
local fixture = require("_work.fixture")
local gitboard = require("_work.gitboard")
local stateclaim = require("_work.stateclaim")
local statewrite = require("_work.statewrite")
local authority = require("_work.stateclaim_authority")
local gitdraft = require("_work.gitdraft")
local graph = require("_work.gitgraph")
local receipt = require("_work.preparation_receipt")
local refsmod = require("_work.refs")
local store = require("_work.store")
local worktree = require("_work.gitworktree")
local SESSION < const > = "11111111111111111111111111111111"
local SCRIPT < const > = [[#!/bin/sh
if [ "$1" = "-e" ]; then printf 'gitboard-runtime-probe-v1\n'; exit 0; fi
if [ -f o/fail ]; then echo precise-build-failure >&2; exit 17; fi
printf '%s\n' "$*" >> o/steps
echo 'build: PASS (fixture)'
]]
local record Case
  s: store.Store
  id: string
  source: string
  base: string
  path: string
  branch: string
  file: string
end

local function value(root: string, ...: string): string
  local r = check.must(child.run({"git", ...}, {cwd = root}))
  assert(r.ok, r.stderr)
  return (r.stdout:gsub("%s+$", ""))
end

local function fresh(name: string, body: function(Case), kind?: string)
  local keys = {"GIT_CONFIG_GLOBAL", "GIT_CONFIG_NOSYSTEM", "GIT_CONFIG_SYSTEM", "GIT_AUTHOR_NAME",
    "GIT_AUTHOR_EMAIL", "GIT_COMMITTER_NAME", "GIT_COMMITTER_EMAIL", "GITBOARD_DRAFT", "GITBOARD_WORKTREE_BOOTSTRAP"}
  local prior: {string: string} = {}
  for _, key in ipairs(keys) do prior[key] = env.get(key); assert(env.unset(key)) end
  local run, print_saved, time, write = child.run, _G.print, os.time, fs.write
  local opened: store.Store
  local ok, err = pcall(function()
      assert(env.set("GIT_CONFIG_GLOBAL", fs.join(fixture.tmpdir, "gitconfig-empty")))
      assert(env.set("GIT_CONFIG_NOSYSTEM", "1"))
      local s = fixture.init_state_repo("adopt-" .. name)
      opened = s
      local _, id = fixture.root_with_leaf(s)
      local source = fs.join(s.root, "product")
      assert(fs.make_dirs(fs.join(source, "bin")))
      fixture.git(source, {"init", "-q"})
      fixture.git(source, {"config", "user.name", "Adoption Fixture"})
      fixture.git(source, {"config", "user.email", "adopt@example.test"})
      fixture.git(source, {"config", "user.useConfigOnly", "true"})
      assert(fs.write(fs.join(source, ".gitignore"), "o/\n"))
      assert(fs.write(fs.join(source, "README"), "base"))
      if kind == "make" then assert(fs.write(fs.join(source, "Makefile"), ".PHONY: bootstrap gate\n")) end
      if kind == "cosmopolitan" then
        assert(fs.make_dirs(fs.join(source, "third_party/lua")))
        assert(fs.write(fs.join(source, "third_party/lua/marker"), "fixture"))
      end
      if kind == nil or kind == "legacy" then
        assert(fs.write(fs.join(source, "bin/cosmic"), kind == "legacy" and "#!/bin/sh\nexit 0\n" or "#!/bin/sh\nexit 99\n"))
        assert(fs.set_mode(fs.join(source, "bin/cosmic"), fs.octal("755")))
      end
      if kind == nil then
        assert(fs.write(fs.join(source, "bin/cosmic.pin"), "url=https://example.test/runtime\nsha256=" .. hash.sha256_hex(SCRIPT) .. "\n"))
      end
      fixture.git(source, {"add", "."}); fixture.git(source, {"commit", "-qm", "base"})
      local base = value(source, "rev-parse", "HEAD")
      fixture.git(source, {"update-ref", "refs/heads/supplied", base})
      assert(graph.cmd_set(s, id, nil, "acme/adopt", "main") == 0)
      fixture.give_spec(s, id)
      fixture.claim_item(s, id, SESSION, base)
      local st = check.must(receipt.confirmed(s, check.must(store.load(s, id)), SESSION))
      local branch = claim.branch(id, st.root)
      assert(fs.make_dirs(fs.join(source, "o/bootstrap")))
      assert(fs.write(fs.join(source, "o/bootstrap/cosmic.ape"), SCRIPT))
      fixture.git(s.root, {"config", "--add", "gitboard.repository", "acme/adopt=" .. source})
      body({s = s, id = id, source = source, base = base, branch = branch,
          path = fs.join(s.root, "wt", branch), file = fs.join(s.root, "receipt.txt")})
    end)
  child.run, _G.print, os.time, fs.write = run, print_saved, time, write
  if opened ~= nil then
    gitdraft.deactivate(opened.root)
    refsmod.clear_overlay(opened.root)
    assert(store.close(opened))
  end
  for _, key in ipairs(keys) do
    if prior[key] == nil then assert(env.unset(key)) else assert(env.set(key, prior[key])) end
  end
  if not ok then error(err, 0) end
end

local function capture(f: function(): integer): integer, string
  local old, lines = _G.print, {}
  _G.print = function(...: any)
    for i = 1, select("#", ...) do lines[#lines + 1] = tostring((select(i, ...))) end
  end
  local ok, code = pcall(f)
  _G.print = old
  if not ok then error(code, 0) end
  return code, table.concat(lines, "\n")
end

local function run(c: Case, adopt?: string, fetch?: boolean, refs?: {string},
    verbose?: boolean, review?: boolean): integer, string
  return capture(function(): integer
      local file: string
      if not review then file = c.file end
      return worktree.cmd_worktree(c.s, c.id, SESSION, c.source, refs or {}, review or false, verbose or false,
        file, nil, nil, adopt, fetch)
    end)
end

local function good(c: Case, adopting?: boolean)
  local code, out = run(c, adopting and c.path or nil)
  assert(code == 0, out)
end

local function test_live_authority_refuses_draft_overlay_wrong_holder_expiry_and_pending()
  for _, fault in ipairs({"draft", "overlay", "holder", "expired", "pending", "unconfirmed"}) do
    fresh("authority-" .. fault, function(c: Case)
        good(c)
        local old = check.must(fs.read(c.file))
        if fault == "draft" then
          local d = check.must(gitdraft.begin(c.s.root))
          assert(env.set("GITBOARD_DRAFT", d.id))
          assert(gitdraft.activate(c.s.root, d))
        elseif fault == "overlay" then
          refsmod.set_overlay(c.s.root, check.must(refsmod.for_each_ref(c.s.root, {"refs/heads"})))
        elseif fault == "holder" then
          fixture.drop_claim(c.s, c.id, SESSION, "different holder")
          fixture.claim_item(c.s, c.id, string.rep("2", 32), c.base)
        elseif fault == "expired" then
          local now = os.time()
          os.time = function(): integer return now + claim.LEASE_S + 1 end
        else
          fixture.drop_claim(c.s, c.id, SESSION, "before speculative reacquisition")
          local canonical = c.s.state_head
          local next_claim = stateclaim.prepare(c.s.root, canonical,
            {{id = c.id, product_base = c.base}}, "take", SESSION, os.time(), false, "")
          assert(next(next_claim.refused) == nil)
          for _, dependency in ipairs(next_claim.dependencies) do
            c.s.state_reads[dependency.path] = dependency.id
          end
          assert(statewrite.transition(c.s, next_claim.changes, "speculative acquisition", next_claim.publish_by))
          fixture.git(c.s.root, {"update-ref", "refs/remotes/origin/state", canonical})
          fixture.git(c.s.root, {"update-ref", "refs/remotes/origin/board/format", canonical})
          assert(refsmod.set_board_mode(c.s.root, "remote"))
          if fault == "unconfirmed" then
            fixture.git(c.s.root, {"update-ref", "refs/heads/state", c.s.state_head})
          end
        end
        local before, original = value(c.s.root, "show-ref"), child.run
        child.run = function(argv: {string}, opts?: child.Options): child.Result | nil, string
          assert(argv[1] == "git", fault .. ": bad authority cannot execute runtime")
          return original(argv, opts)
        end
        local code, out = run(c, c.path)
        assert(code ~= 0, fault .. ": " .. out)
        assert(check.must(fs.read(c.file)) == old and value(c.s.root, "show-ref") == before)
      end)
  end
end

local function test_pending_renewal_preserves_current_acquisition_authority()
  fresh("pending-renewal", function(c: Case)
      good(c)
      local current = check.must(authority.current(c.s, c.id, SESSION))
      local renewal = stateclaim.prepare(c.s.root, c.s.state_head,
        {{id = c.id, product_base = ""}}, "renew", SESSION, os.time() + 1, false, "")
      assert(next(renewal.refused) == nil and #renewal.changes == 1)
      for _, dependency in ipairs(renewal.dependencies) do
        c.s.state_reads[dependency.path] = dependency.id
      end
      assert(statewrite.transition(c.s, renewal.changes, "pending renewal", renewal.publish_by))
      local still_current = check.must(authority.current(c.s, c.id, SESSION))
      assert(still_current.root == current.root and still_current.expires_at == current.expires_at)
      local code, out = run(c, c.path)
      assert(code == 0, "pending renewal cannot invalidate the current canonical lease: " .. out)
    end)
end

local function test_options_unsupported_targets_and_legacy_compatibility()
  for _, kind in ipairs({"legacy", "absent", "make", "cosmopolitan"}) do
    fresh("compat-" .. kind, function(c: Case)
        good(c)
        local code, out = run(c, c.path)
        assert(code ~= 0 and out:find("require a tracked pinned cosmic target", 1, true), out)
      end, kind)
    fresh("unsupported-fetch-" .. kind, function(c: Case)
        local code, out = run(c, nil, true)
        assert(code ~= 0 and out:find("require a tracked pinned cosmic target", 1, true), out)
      end, kind)
  end
  fresh("options", function(c: Case)
      for _, args in ipairs({{"--adopt", ""}, {"--adopt", c.path}, {"--receipt-out", ""},
          {"--review", "--adopt", c.path, "--receipt-out", c.file}}) do
        local code = capture(function(): integer
            local argv = {"worktree", c.id, "--dir", c.s.root, "--session", SESSION}
            for _, word in ipairs(args) do argv[#argv + 1] = word end
            return gitboard.main(table.unpack(argv))
          end)
        assert(code ~= 0 and not fs.is_dir(c.path))
      end
      assert(env.set("GITBOARD_WORKTREE_BOOTSTRAP", "0"))
      assert(run(c, c.path) ~= 0 and run(c, nil, true) ~= 0)
      good(c)
    end)
end
