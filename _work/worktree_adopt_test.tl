#!/usr/bin/env cosmic
-- Adoption's success paths, its claim/authority checks, and unsupported
-- targets. `_work/worktree_adopt_refusal_test.tl` carries the checkout
-- refusal, manual/review, real-alias, and submodule cases — split out
-- so the ~47 independent `fresh()` fixture repositories both files
-- build together run across two processes instead of one.
local check = require("cosmic.check")
local child = require("cosmic.child")
local env = require("cosmic.env")
local fs = require("cosmic.fs")
local hash = require("cosmic.hash")
local brief = require("_work.brief")
local claim = require("_work.claim")
local fixture = require("_work.fixture")
local gitboard = require("_work.gitboard")
local gitclaim = require("_work.gitclaim")
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

local function test_public_cli_fresh_then_adoption_and_receipt_backed_brief()
  fresh("public", function(c: Case)
      local function public(adopt: boolean, fetch?: boolean): integer
        local argv = {"worktree", c.id, "--dir", c.s.root, "--session", SESSION, "--receipt-out", c.file}
        if adopt then argv[#argv + 1], argv[#argv + 2] = "--adopt", c.path end
        if fetch then argv[#argv + 1] = "--fetch" end
        return gitboard.main(table.unpack(argv))
      end
      local code, out = capture(function(): integer return public(false) end)
      assert(code == 0, out)
      local old = check.must(fs.read(c.file))
      local fields = receipt.decode(old)
      assert(fields.branch == c.branch and fields.worktree == c.path and fields["product-base"] == c.base)
      assert(fields.session == SESSION)
      assert(fs.write(fs.join(c.path, "untracked-user-file"), "keep"))
      assert(fs.write(fs.join(c.path, "o/warm-artifact"), "keep warm"))
      local before = value(c.s.root, "show-ref")
      local config = check.must(fs.read(fs.join(c.source, ".git/config")))
      local original, adds = child.run, 0
      child.run = function(argv: {string}, opts?: child.Options): child.Result | nil, string
        if argv[1] == "git" and argv[2] == "worktree" and argv[3] == "add" then adds = adds + 1 end
        assert(argv[1] ~= "curl")
        return original(argv, opts)
      end
      code, out = capture(function(): integer return public(true) end)
      assert(code == 0 and adds == 0, out)
      assert(value(c.s.root, "show-ref") == before and check.must(fs.read(fs.join(c.source, ".git/config"))) == config)
      assert(check.must(fs.read(fs.join(c.path, "untracked-user-file"))) == "keep")
      assert(check.must(fs.read(fs.join(c.path, "o/warm-artifact"))) == "keep warm")
      assert(check.must(fs.read(fs.join(c.path, "o/steps"))) == "--make build\n--make build\n")
      assert(check.must(fs.read(c.file)) == old)
      code, out = capture(function(): integer return public(true, true) end)
      assert(code == 0, out)
      assert(check.must(fs.read(fs.join(c.path, "o/steps"))) == "--make build\n--make build\n--make fetch\n--make build\n")
      code, out = capture(function(): integer
          return brief.cmd_brief(c.s, "builder", c.id, nil, c.path, c.file, SESSION)
        end)
      assert(code == 0 and out:find("gitboard-builder-preparation-v1", 1, true), out)
      assert(run(c) ~= 0, "ordinary repeat still refuses")
    end)
end

local function test_failed_build_or_receipt_write_retains_checkout_for_explicit_adoption()
  for _, cause in ipairs({"build", "receipt"}) do
    fresh("retention-" .. cause, function(c: Case)
        local original, write = child.run, fs.write
        child.run = function(argv: {string}, opts?: child.Options): child.Result | nil, string
          local r, err = original(argv, opts)
          if cause == "build" and argv[2] == "worktree" and argv[3] == "add" then
            assert(fs.make_dirs(fs.join(c.path, "o")))
            assert(fs.write(fs.join(c.path, "o/fail"), "fail"))
          end
          return r, err
        end
        assert(fs.write(c.file, "older receipt"))
        fs.write = function(path: string, text: string, opts?: fs.WriteOptions): boolean, string
          if cause == "receipt" and path == c.file then return false, "receipt output failed" end
          return write(path, text, opts)
        end
        local code, out = run(c)
        assert(code ~= 0 and out:find("checkout created at " .. c.path, 1, true), out)
        assert(out:find("--adopt", 1, true) and check.must(fs.read(c.file)) == "older receipt")
        if cause == "build" then
          assert(out:find("precise-build-failure", 1, true), out)
          assert(fs.remove(fs.join(c.path, "o/fail")))
        end
        child.run, fs.write = original, write
        good(c, true)
        assert(receipt.decode(check.must(fs.read(c.file)))["product-base"] == c.base)
      end)
  end
end

local function test_final_live_claim_expiry_reacquisition_and_confirmed_renewal()
  for _, action in ipairs({"expired", "reacquired", "renewed"}) do
    fresh("claim-" .. action, function(c: Case)
        good(c)
        local original, now, changed = child.run, os.time(), false
        local old = check.must(fs.read(c.file))
        local initial = receipt.decode(old)
        child.run = function(argv: {string}, opts?: child.Options): child.Result | nil, string
          local r, err = original(argv, opts)
          if argv[#argv] == "build" and not changed then
            changed = true
            if action == "expired" then os.time = function(): integer return now + claim.LEASE_S + 2 end
            elseif action == "renewed" then
              os.time = function(): integer return now + 1 end
              fixture.control_claim(c.s, {c.id}, SESSION, "renew")
            else
              fixture.drop_claim(c.s, c.id, SESSION, "reacquire during build")
              fixture.claim_item(c.s, c.id, SESSION, c.base)
            end
          end
          return r, err
        end
        local code, out = run(c, c.path, false, {"refs/heads/supplied"})
        assert(changed)
        if action == "renewed" then
          assert(code == 0, out)
          local fields = receipt.decode(check.must(fs.read(c.file)))
          assert(fields["claim-fact"] == initial["claim-fact"] and fields["claim-control"] ~= initial["claim-control"])
        else
          assert(code ~= 0 and out:find("checkout retained", 1, true), out)
          assert(check.must(fs.read(c.file)) == old)
          local r = check.must(original({"git", "show-ref", "--verify", "--quiet", "refs/spike/supplied"}, {cwd = c.path}))
          assert(not r.ok, "final live authority precedes prepared-ref writes")
        end
      end)
  end
end

local function test_final_checkout_and_private_runtime_changes_precede_refs_and_receipt()
  for _, fault in ipairs({"head", "branch", "dirty", "identity", "pin", "runtime"}) do
    fresh("final-" .. fault, function(c: Case)
        good(c)
        local original, old = child.run, check.must(fs.read(c.file))
        child.run = function(argv: {string}, opts?: child.Options): child.Result | nil, string
          local r, err = original(argv, opts)
          if argv[#argv] == "build" then
            if fault == "head" then fixture.git(c.path, {"commit", "--allow-empty", "-qm", "changed"})
            elseif fault == "branch" then fixture.git(c.path, {"checkout", "-qb", "changed"})
            elseif fault == "dirty" then assert(fs.write(fs.join(c.path, "README"), "dirty"))
            elseif fault == "identity" then fixture.git(c.path, {"config", "user.name", ""})
            elseif fault == "pin" then assert(fs.write(fs.join(c.path, "bin/cosmic.pin"), "changed"))
            else assert(fs.write(argv[1], "runtime changed")) end
          end
          return r, err
        end
        local code, out = run(c, c.path, false, {"refs/heads/supplied"})
        assert(code ~= 0 and out:find("checkout retained", 1, true), out)
        assert(check.must(fs.read(c.file)) == old)
        local r = check.must(original({"git", "show-ref", "--verify", "--quiet", "refs/spike/supplied"}, {cwd = c.path}))
        assert(not r.ok, "post-build validation must precede refs")
      end)
  end
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
          local target = gitclaim.target_item_ref(c.id)
          local p = check.must(gitclaim.prepare_batch({{root = c.s.root, id = c.id, source_ref = target,
                  target_ref = target, remote = "origin", batch = "pending-renewal", caller = SESSION,
                  action = "renew", product_base = "", force = false, why = "", now = os.time() + 1}}).prepared)
          for _, update in ipairs(p.transaction.updates) do
            if fault == "pending" or update.ref == target then
              fixture.git(c.s.root, {"update-ref", update.ref, update.next})
            end
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
