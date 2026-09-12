#!/usr/bin/env cosmic
-- Bootstrap failure, signal-termination, and success postconditions,
-- split out of `_work/gitworktree_bootstrap_test.tl` so its heaviest
-- cases (the 2x2x2 and 2x2 fault matrices below) run in their own
-- process alongside that file's remaining cases rather than serialized
-- after them. The `fresh`/`isolated`/`capture` harness below is
-- deliberately duplicated from that file rather than shared, matching
-- this repo's existing split convention (see `_work/storeref_test.tl`).
--
-- Preparation postconditions use real isolated Git checkouts; bootstrap
-- programs are committed shell stubs or mocked subprocess calls, never
-- downloads or a real host toolchain.
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
    -- A stable detach target with bin/cosmic already present: the
    -- moved-head fixture's script checks this out instead of a relative
    -- ancestor, so the fetch-then-build plan's second step still finds
    -- the executable after the first moves HEAD.
    assert(fs.write(fs.join(root, "bin/cosmic"), "#!/bin/sh\nexit 0\n"))
    assert(fs.set_mode(fs.join(root, "bin/cosmic"), tonumber("755", 8)))
    git(root, {"add", "bin/cosmic"})
    git(root, {"commit", "-q", "-m", "decoy"})
    git(root, {"branch", "decoy"})
    assert(fs.write(fs.join(root, "bin/cosmic"), "#!/bin/sh\n" .. (script or "exit 0\n")))
    assert(fs.set_mode(fs.join(root, "bin/cosmic"), tonumber("755", 8)))
  elseif kind == "make-bootstrap" then
    assert(fs.write(fs.join(root, "Makefile"),
        ".PHONY: bootstrap\nbootstrap:\n\ttouch bootstrap-ran\n"))
  elseif kind == "make-none" then
    assert(fs.write(fs.join(root, "Makefile"), ".PHONY: gate\ngate:\n\ttrue\n"))
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
          assert(out:find("bin/cosmic --make fetch failed (signal 15)", 1, true) ~= nil, out)
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
        assert(code == 0 and out:find("bootstrap: cosmic (fetch + build)", 1, true) ~= nil, out)
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
