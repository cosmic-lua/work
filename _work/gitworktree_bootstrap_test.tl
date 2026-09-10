#!/usr/bin/env cosmic
-- Preparation postconditions use real isolated Git checkouts; bootstrap
-- programs are committed shell stubs, never downloads or host toolchains.
local check = require("cosmic.check")
local child = require("cosmic.child")
local env = require("cosmic.env")
local fixture = require("_work.fixture")
local fs = require("cosmic.fs")
local gitclaim = require("_work.gitclaim")
local graph = require("_work.gitgraph")
local prepared = require("_work.prepared")
local store = require("_work.store")
local storewrite = require("_work.storewrite")
local worktree = require("_work.gitworktree")

local SESSION < const > = "11111111111111111111111111111111"
local git = fixture.git
local record Case
  s: store.Store
  id: string
  root: string
  base: string
  head: string
  branch: string
  path: string
end

local function git_output(root: string, argv: {string}): string
  local args: {string} = {"git"}
  for _, value in ipairs(argv) do args[#args + 1] = value end
  local r = check.must(child.run(args, {cwd = root}))
  assert(r.ok, r.stderr)
  return (r.stdout:gsub("%s+$", ""))
end

local function fresh(name: string, kind: string, script?: string): Case
  local dir = fs.join(fixture.tmpdir, "worktree-bootstrap-" .. name)
  assert(fs.remove_all(dir) and fs.make_dirs(dir))
  local root = fs.join(dir, "product")
  assert(fs.make_dirs(root))
  git(root, {"init", "-q"})
  git(root, {"checkout", "-q", "-b", "main"})
  git(root, {"config", "user.name", "Bootstrap Fixture"})
  git(root, {"config", "user.email", "bootstrap@example.test"})
  git(root, {"config", "user.useConfigOnly", "true"})
  assert(fs.write(fs.join(root, "README"), "initial\n"))
  git(root, {"add", "README"})
  git(root, {"commit", "-q", "-m", "initial"})
  if kind == "cosmic" then
    assert(fs.make_dirs(fs.join(root, "bin")))
    assert(fs.write(fs.join(root, "bin/cosmic"), "#!/bin/sh\n" .. (script or "exit 0\n")))
    assert(fs.set_mode(fs.join(root, "bin/cosmic"), tonumber("755", 8)))
  elseif kind == "cosmopolitan" then
    assert(fs.make_dirs(fs.join(root, "third_party/lua")))
    assert(fs.write(fs.join(root, "third_party/lua/lua.c"), ""))
  end
  assert(fs.write(fs.join(root, "README"), "base\n"))
  git(root, {"add", "-A"})
  git(root, {"commit", "-q", "-m", "base"})
  local base = git_output(root, {"rev-parse", "HEAD"})
  assert(fs.write(fs.join(root, "README"), "review\n"))
  git(root, {"commit", "-q", "-am", "review head"})
  local head = git_output(root, {"rev-parse", "HEAD"})
  git(root, {"update-ref", "refs/heads/supplied", head})
  local s = fixture.init_state_repo("bootstrap-" .. name)
  local _, id = fixture.root_with_leaf(s)
  assert(graph.cmd_set(s, id, nil, "acme/widgets", "main") == 0)
  local it = check.must(store.load(s, id))
  it.handover_head = head
  assert(storewrite.save(s, it, "fixture handover"))
  local target = gitclaim.target_item_ref(id)
  local claimed = gitclaim.prepare_batch({{
        root = s.root, id = id, source_ref = target, target_ref = target,
        remote = "origin", batch = "bootstrap-" .. name, caller = SESSION,
        action = "take", product_base = base, force = false, why = "", now = os.time(),
      }})
  assert(claimed.prepared ~= nil, claimed.refused[id] or claimed.refused.batch)
  assert(prepared.promote_local(s.root, claimed.prepared.transaction))
  local branch = claimed.prepared.members[1].branch
  return {s = s, id = id, root = root, base = base, head = head, branch = branch,
    path = fs.join(dir, "wt", branch)}
end

-- Every mock is restored even if a production error or assertion escapes.
local function isolated(f: function())
  local keys = {"GIT_AUTHOR_NAME", "GIT_AUTHOR_EMAIL", "GIT_COMMITTER_NAME",
    "GIT_COMMITTER_EMAIL", "GITBOARD_WORKTREE_BOOTSTRAP"}
  local prior: {string: string} = {}
  for _, key in ipairs(keys) do
    prior[key] = env.get(key)
    assert(env.unset(key))
  end
  local old_run, old_print = child.run, _G.print
  local ok, err = pcall(f)
  child.run, _G.print = old_run, old_print
  for _, key in ipairs(keys) do
    if prior[key] == nil then assert(env.unset(key))
    else assert(env.set(key, prior[key])) end
  end
  if not ok then error(err, 0) end
end

local function capture(c: Case, review: boolean, verbose: boolean,
    refs?: {string}, root_override?: string): integer, string
  local old_print = _G.print
  local lines: {string} = {}
  _G.print = function(...: any)
    local parts: {string} = {}
    for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
    lines[#lines + 1] = table.concat(parts, "\t")
  end
  local ok, code = pcall(worktree.cmd_worktree, c.s, c.id, SESSION,
    root_override or c.root, refs or {}, review, verbose)
  _G.print = old_print
  if not ok then error(code, 0) end
  return code, table.concat(lines, "\n")
end

local function assert_created_failure(c: Case, code: integer, out: string)
  assert(code ~= 0, out)
  assert(out:find("checkout created at " .. c.path .. "; preparation failed:",
      1, true) ~= nil, out)
  assert(out:find("(bootstrap:", 1, true) == nil, "no successful final verdict: " .. out)
end

local function test_bootstrap_failures_propagate_in_both_modes_and_roles()
  for _, review in ipairs({false, true}) do
    for _, verbose in ipairs({false, true}) do
      for _, spawn in ipairs({false, true}) do
        isolated(function()
            local name = "failure-" .. tostring(review) .. tostring(verbose) .. tostring(spawn)
            local c = fresh(name, "cosmic", "echo probe-out\necho probe-err >&2\nexit 17\n")
            local board = check.must(store.git_ok(c.s, {"show-ref"})).stdout
            local original = child.run
            local seen = false
            child.run = function(argv: {string}, opts?: child.Options): child.Result | nil, string
              if argv[1] == "bin/cosmic" then
                seen = true
                assert(opts ~= nil and opts.cwd == c.path)
                assert((opts.stdout == "inherit") == verbose)
                assert((opts.stderr == "inherit") == verbose)
                if spawn then return nil, "probe spawn failure" end
              end
              return original(argv, opts)
            end
            local code, out = capture(c, review, verbose, {"refs/heads/supplied"})
            child.run = original
            assert(seen, "bootstrap was attempted")
            assert_created_failure(c, code, out)
            assert(out:find(spawn and "probe spawn failure" or "exit 17", 1, true) ~= nil, out)
            if not verbose and not spawn then
              assert(out:find("probe-out", 1, true) ~= nil and out:find("probe-err", 1, true) ~= nil, out)
            end
            assert(fs.is_dir(c.path), "failed checkout is retained")
            assert(git_output(c.path, {"rev-parse", "HEAD"}) == (review and c.head or c.base))
            assert(git_output(c.root, {"rev-parse", "refs/heads/" .. c.branch}) ~= "")
            local ref = check.must(child.run({"git", "show-ref", "--verify", "--quiet",
                  "refs/spike/supplied"}, {cwd = c.root}))
            assert(not ref.ok, "failed bootstrap must not copy prepared refs")
            assert(check.must(store.git_ok(c.s, {"show-ref"})).stdout == board)
            assert(store.close(c.s))
          end)
      end
    end
  end
end

local function test_signal_termination_reports_failure_in_both_modes_and_roles()
  for _, review in ipairs({false, true}) do
    for _, verbose in ipairs({false, true}) do
      isolated(function()
          local c = fresh("signal-" .. tostring(review) .. tostring(verbose), "cosmic",
            "echo signal-out\necho signal-err >&2\nkill -TERM $$\n")
          local board = check.must(store.git_ok(c.s, {"show-ref"})).stdout
          local original = child.run
          local seen = false
          child.run = function(argv: {string}, opts?: child.Options): child.Result | nil, string
            if argv[1] == "bin/cosmic" then
              seen = true
              assert(opts ~= nil and opts.cwd == c.path)
              assert((opts.stdout == "inherit") == verbose)
              assert((opts.stderr == "inherit") == verbose)
            end
            return original(argv, opts)
          end
          local code, out = capture(c, review, verbose, {"refs/heads/supplied"})
          assert(seen, "bootstrap was attempted")
          assert_created_failure(c, code, out)
          assert(out:find("bin/cosmic --make build failed (signal 15)", 1, true) ~= nil, out)
          if not verbose then
            assert(out:find("signal-out", 1, true) ~= nil and out:find("signal-err", 1, true) ~= nil, out)
          end
          assert(fs.is_dir(c.path), "signal-terminated checkout is retained")
          assert(git_output(c.path, {"rev-parse", "HEAD"}) == (review and c.head or c.base))
          assert(git_output(c.root, {"rev-parse", "refs/heads/" .. c.branch}) ~= "")
          local ref = check.must(child.run({"git", "show-ref", "--verify", "--quiet",
                "refs/spike/supplied"}, {cwd = c.root}))
          assert(not ref.ok, "signal termination must not copy prepared refs")
          assert(check.must(store.git_ok(c.s, {"show-ref"})).stdout == board)
          assert(store.close(c.s))
        end)
    end
  end
end

local function test_success_preserves_exact_heads_and_inherited_identity()
  for _, review in ipairs({false, true}) do
    isolated(function()
        local c = fresh("success-" .. tostring(review), "cosmic", "echo 'build: PASS (fixture)'\n")
        local config = check.must(fs.read(fs.join(c.root, ".git/config")))
        local code, out = capture(c, review, false, {"refs/heads/supplied"})
        assert(code == 0 and out:find("bootstrap: cosmic (local build)", 1, true) ~= nil, out)
        assert(git_output(c.path, {"rev-parse", "HEAD"}) == (review and c.head or c.base))
        assert(git_output(c.path, {"rev-parse", "refs/spike/supplied"}) == c.head)
        for _, key in ipairs({"GIT_AUTHOR_IDENT", "GIT_COMMITTER_IDENT"}) do
          assert(git_output(c.path, {"var", key}):find("Bootstrap Fixture <bootstrap@example.test>",
              1, true) ~= nil, "the checkout inherits repository-local identity")
        end
        assert(check.must(fs.read(fs.join(c.root, ".git/config"))) == config)
        assert(out:find("bootstrap@example.test", 1, true) == nil, "do not print identity values")
        assert(store.close(c.s))
      end)
  end
end

local function test_missing_created_directory_is_not_success()
  isolated(function()
      local c = fresh("missing-created", "none")
      local original = child.run
      child.run = function(argv: {string}, opts?: child.Options): child.Result | nil, string
        if argv[1] == "git" and argv[2] == "worktree" and argv[3] == "add" then
          return original({"git", "--version"}, opts)
        end
        return original(argv, opts)
      end
      local code, out = capture(c, false, false)
      assert_created_failure(c, code, out)
      assert(out:find("checkout directory is missing", 1, true) ~= nil, out)
      assert(not fs.is_dir(c.path))
      assert(store.close(c.s))
    end)
end

local function test_bootstrap_moving_head_is_refused_at_final_validation()
  for _, review in ipairs({false, true}) do
    isolated(function()
        local c = fresh("moved-head-" .. tostring(review), "cosmic", "git checkout -q --detach HEAD^\n")
        local code, out = capture(c, review, false)
        assert_created_failure(c, code, out)
        assert(out:find("does not equal requested commit", 1, true) ~= nil, out)
        assert(fs.is_dir(c.path))
        assert(store.close(c.s))
      end)
  end
end

local function test_missing_author_or_committer_refuses_before_creation()
  for _, author_override in ipairs({false, true}) do
    isolated(function()
        local c = fresh("identity-" .. tostring(author_override), "cosmic")
        git(c.root, {"config", "user.name", ""})
        git(c.root, {"config", "user.email", ""})
        if author_override then
          assert(env.set("GIT_AUTHOR_NAME", "Valid Author"))
          assert(env.set("GIT_AUTHOR_EMAIL", "author@example.test"))
        end
        local code, out = capture(c, false, false)
        assert(code ~= 0, out)
        local key = author_override and "GIT_COMMITTER_IDENT" or "GIT_AUTHOR_IDENT"
        assert(out:find(key .. " unavailable in " .. c.root, 1, true) ~= nil, out)
        assert(out:find("config --local KEY VALUE", 1, true) ~= nil, out)
        assert(out:find("user.name and user.email", 1, true) ~= nil, out)
        assert(not fs.is_dir(c.path), "identity preflight precedes checkout creation")
        local branch = check.must(child.run({"git", "show-ref", "--verify", "--quiet",
              "refs/heads/" .. c.branch}, {cwd = c.root}))
        assert(not branch.ok, "identity preflight creates no branch")
        assert(store.close(c.s))
      end)
  end
end

local function test_identity_environment_overrides_are_respected()
  isolated(function()
      local c = fresh("identity-environment", "none")
      git(c.root, {"config", "user.name", ""})
      git(c.root, {"config", "user.email", ""})
      for _, role in ipairs({"AUTHOR", "COMMITTER"}) do
        assert(env.set("GIT_" .. role .. "_NAME", "Environment Identity"))
        assert(env.set("GIT_" .. role .. "_EMAIL", "environment@example.test"))
      end
      local code, out = capture(c, false, false)
      assert(code == 0, out)
      assert(git_output(c.path, {"var", "GIT_COMMITTER_IDENT"}):find("Environment Identity", 1, true) ~= nil)
      assert(store.close(c.s))
    end)
end

local function test_identity_spawn_failure_preserves_the_underlying_error()
  isolated(function()
      local c = fresh("identity-spawn", "none")
      local original = child.run
      child.run = function(argv: {string}, opts?: child.Options): child.Result | nil, string
        if argv[1] == "git" and argv[2] == "var" then return nil, "identity probe could not spawn" end
        return original(argv, opts)
      end
      local code, out = capture(c, false, false)
      assert(code ~= 0 and out:find("identity probe could not spawn", 1, true) ~= nil, out)
      assert(not fs.is_dir(c.path))
      assert(store.close(c.s))
    end)
end

local function test_source_only_worktree_identity_does_not_imply_target_identity()
  isolated(function()
      local c = fresh("worktree-identity", "cosmic")
      git(c.root, {"config", "user.name", ""})
      git(c.root, {"config", "user.email", ""})
      git(c.root, {"config", "extensions.worktreeConfig", "true"})
      -- Git may copy config.worktree when adding a checkout. Keep this identity
      -- genuinely source-only even when the conditional directive is copied.
      local identity = fs.join(c.root, "source-identity")
      assert(fs.write(identity, "[user]\nname = Source Only\nemail = source@example.test\n"))
      git(c.root, {"config", "--worktree", "includeIf.gitdir:" .. c.root .. "/.git.path", identity})
      assert(git_output(c.root, {"var", "GIT_AUTHOR_IDENT"}):find("Source Only", 1, true) ~= nil)
      local before = check.must(fs.read(fs.join(c.root, ".git/config")))
      local code, out = capture(c, false, false)
      assert_created_failure(c, code, out)
      assert(out:find("GIT_AUTHOR_IDENT unavailable in " .. c.path, 1, true) ~= nil, out)
      assert(fs.is_dir(c.path))
      assert(check.must(fs.read(fs.join(c.root, ".git/config"))) == before)
      assert(store.close(c.s))
    end)
end

local function test_bootstrap_identity_changes_are_rechecked()
  isolated(function()
      local c = fresh("changed-identity", "cosmic", "git config user.name ''\n")
      local code, out = capture(c, false, false)
      assert_created_failure(c, code, out)
      assert(out:find("GIT_AUTHOR_IDENT unavailable in " .. c.path, 1, true) ~= nil, out)
      assert(store.close(c.s))
    end)
end

local function test_skipping_is_explicit_and_still_checks_identity()
  isolated(function()
      local c = fresh("skip", "cosmic", "touch bootstrap-ran\nexit 17\n")
      assert(env.set("GITBOARD_WORKTREE_BOOTSTRAP", "0"))
      local code, out = capture(c, false, false)
      assert(code == 0, out)
      assert(out:find("bootstrap: cosmic (skipped: GITBOARD_WORKTREE_BOOTSTRAP=0)", 1, true) ~= nil, out)
      assert(not fs.is_file(fs.join(c.path, "bootstrap-ran")))
      assert(git_output(c.path, {"rev-parse", "HEAD"}) == c.base)
      assert(store.close(c.s))
      c = fresh("skip-invalid", "cosmic")
      git(c.root, {"config", "user.name", ""})
      code, out = capture(c, false, false)
      assert(code ~= 0 and not fs.is_dir(c.path), "skipping must not skip identity")
      assert(store.close(c.s))
    end)
end

local function test_no_action_trees_keep_their_honest_labels()
  for _, kind in ipairs({"none", "cosmopolitan"}) do
    isolated(function()
        local c = fresh("no-action-" .. kind, kind)
        local code, out = capture(c, false, false)
        local label = kind == "none" and "nothing (unrecognized tree)" or "cosmopolitan (nothing needed)"
        assert(code == 0 and out:find("bootstrap: " .. label, 1, true) ~= nil, out)
        assert(git_output(c.path, {"rev-parse", "HEAD"}) == c.base)
        assert(store.close(c.s))
      end)
  end
end

local function test_prepared_ref_failure_names_the_preserved_checkout()
  isolated(function()
      local c = fresh("missing-ref", "none")
      local code, out = capture(c, false, false, {"refs/heads/absent"})
      assert_created_failure(c, code, out)
      assert(out:find("prepared ref refs/heads/absent is missing", 1, true) ~= nil, out)
      assert(fs.is_dir(c.path))
      assert(store.close(c.s))
    end)
end

-- The recovery line echoes --repo-dir only when the failing invocation
-- itself supplied one; a run resolved through the configured map must not
-- be told to pass a flag it never used.
local function test_recovery_line_echoes_repo_dir_only_when_supplied()
  local script = "exit 17\n"
  isolated(function()
      local c = fresh("recovery-override", "cosmic", script)
      local code, out = capture(c, false, false, {}, c.root)
      assert_created_failure(c, code, out)
      assert(out:find("--adopt", 1, true) ~= nil, out)
      assert(out:find("--receipt-out FILE", 1, true) ~= nil, out)
      assert(out:find(("--repo-dir %q"):format(c.root), 1, true) ~= nil, out)
      assert(out:find("--root", 1, true) == nil, out)
      assert(store.close(c.s))
    end)
  isolated(function()
      local c = fresh("recovery-mapped", "cosmic", script)
      git(c.s.root, {"config", "--local", "--add", "gitboard.repository",
          "acme/widgets=" .. c.root})
      local code, out = capture(c, false, false, {}, "")
      assert_created_failure(c, code, out)
      assert(out:find("--adopt", 1, true) ~= nil, out)
      assert(out:find("--receipt-out FILE", 1, true) ~= nil, out)
      assert(out:find("--repo-dir", 1, true) == nil, out)
      assert(out:find("--root", 1, true) == nil, out)
      assert(store.close(c.s))
    end)
end
