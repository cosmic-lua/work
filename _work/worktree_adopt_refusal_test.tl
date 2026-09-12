#!/usr/bin/env cosmic
-- Adoption checkout refusals, plus manual/review/submodule shapes, split
-- out of `_work/worktree_adopt_test.tl` so the ~20 independent
-- `fresh()` fixture repositories these cases build run in their own
-- process alongside that file's remaining cases rather than serialized
-- after them. The `fresh`/`capture`/`run`/`good` harness below is
-- deliberately duplicated from that file rather than shared, matching
-- this repo's existing split convention (see `_work/storeref_test.tl`).
local check = require("cosmic.check")
local child = require("cosmic.child")
local env = require("cosmic.env")
local fs = require("cosmic.fs")
local hash = require("cosmic.hash")
local claim = require("_work.claim")
local fixture = require("_work.fixture")
local gitdraft = require("_work.gitdraft")
local graph = require("_work.gitgraph")
local receipt = require("_work.preparation_receipt")
local refsmod = require("_work.refs")
local store = require("_work.store")
local storewrite = require("_work.storewrite")
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

local function test_every_adoption_checkout_refusal_preserves_refs_config_and_receipt()
  for _, fault in ipairs({"nested", "alias", "dirty", "index", "head", "branch", "detached", "registration",
      "common", "author", "committer", "pin", "missing", "status-error"}) do
    fresh("refuse-" .. fault, function(c: Case)
        good(c)
        local path, original = c.path, child.run
        if fault == "nested" then path = fs.join(c.path, "bin")
        elseif fault == "alias" then path = c.path .. "/."
        elseif fault == "dirty" or fault == "index" then
          assert(fs.write(fs.join(c.path, "README"), "dirty"))
          if fault == "index" then fixture.git(c.path, {"add", "README"}) end
        elseif fault == "head" then fixture.git(c.path, {"commit", "--allow-empty", "-qm", "moved"})
        elseif fault == "branch" then fixture.git(c.path, {"checkout", "-qb", "wrong-branch"})
        elseif fault == "detached" then fixture.git(c.path, {"checkout", "-q", "--detach"})
        elseif fault == "author" or fault == "committer" then
          fixture.git(c.path, {"config", "user.name", ""})
          fixture.git(c.path, {"config", "user.email", ""})
          if fault == "committer" then
            assert(env.set("GIT_AUTHOR_NAME", "Author")); assert(env.set("GIT_AUTHOR_EMAIL", "a@example.test"))
          end
        elseif fault == "pin" then assert(fs.write(fs.join(c.path, "bin/cosmic.pin"), "changed"))
        elseif fault == "missing" then path = c.path .. "-missing"
        end
        local before, config, old = value(c.s.root, "show-ref"), check.must(fs.read(fs.join(c.source, ".git/config"))),
        check.must(fs.read(c.file))
        child.run = function(argv: {string}, opts?: child.Options): child.Result | nil, string
          assert(argv[1] == "git", fault .. ": refusal must precede runtime execution")
          assert(not (argv[2] == "worktree" and argv[3] == "add"), "adoption never creates")
          if fault == "status-error" and argv[2] == "status" then
            return {ok = false, code = -1, signal = 15, stdout = "", stderr = ""}, ""
          end
          if fault == "registration" and argv[2] == "worktree" and argv[3] == "list" then
            return {ok = true, code = 0, stdout = "", stderr = ""}, ""
          end
          if fault == "common" and opts ~= nil and opts.cwd == c.path and argv[4] == "--git-common-dir" then
            return {ok = true, code = 0, stdout = "/unrelated/.git\n", stderr = ""}, ""
          end
          return original(argv, opts)
        end
        local code, out = run(c, path)
        assert(code ~= 0 and out:find("checkout retained", 1, true), fault .. ": " .. out)
        assert(check.must(fs.read(c.file)) == old)
        assert(value(c.s.root, "show-ref") == before and check.must(fs.read(fs.join(c.source, ".git/config"))) == config)
      end)
  end
end

local function test_manual_canonical_checkout_and_source_head_difference_are_supported()
  fresh("manual", function(c: Case)
      fixture.git(c.source, {"commit", "--allow-empty", "-qm", "source ahead"})
      fixture.git(c.source, {"worktree", "add", "-q", "-b", c.branch, c.path, c.base})
      good(c, true)
      assert(value(c.path, "rev-parse", "HEAD") == c.base)
    end)
end

local function test_review_cache_preparation_and_verbosity_modes()
  for _, verbose in ipairs({false, true}) do
    fresh("review-" .. tostring(verbose), function(c: Case)
        local it = check.must(store.load(c.s, c.id))
        it.handover_head = c.base
        assert(storewrite.save(c.s, it, "fixture handover"))
        local code, out = run(c, nil, false, {}, verbose, true)
        assert(code == 0 and out:find("review at", 1, true), out)
        assert(not fs.is_present(c.file))
      end)
  end
end

local function test_real_unrelated_repository_and_symlink_cannot_adopt_canonical_spelling()
  for _, link in ipairs({false, true}) do
    fresh("real-alias-" .. tostring(link), function(c: Case)
        good(c)
        assert(fs.move(c.path, c.path .. "-original"))
        if link then assert(fs.symlink(c.path .. "-original", c.path))
        else
          fixture.git(c.s.root, {"clone", "-q", c.source, c.path})
          fixture.git(c.path, {"checkout", "-q", "-b", c.branch, c.base})
        end
        local code, out = run(c, c.path)
        assert(code ~= 0, out)
        if link then assert(out:find("exact Git toplevel", 1, true) or out:find("symlink", 1, true), out)
        else assert(out:find("common directory mismatch", 1, true), out) end
      end)
  end
end

local function test_tracked_submodule_dirt_is_not_hidden_by_omitting_untracked_files()
  fresh("submodule", function(c: Case)
      local module = fs.join(c.s.root, "module-source")
      assert(fs.make_dirs(module))
      fixture.git(module, {"init", "-q"})
      assert(fs.write(fs.join(module, "tracked"), "clean"))
      fixture.git(module, {"add", "."}); fixture.git(module, {"commit", "-qm", "module"})
      fixture.git(c.source, {"-c", "protocol.file.allow=always", "submodule", "add", "-q", module, "sub"})
      fixture.git(c.source, {"commit", "-qm", "add submodule"})
      c.base = value(c.source, "rev-parse", "HEAD")
      fixture.drop_claim(c.s, c.id, SESSION, "fixture new base")
      fixture.claim_item(c.s, c.id, SESSION, c.base)
      local st = check.must(receipt.confirmed(c.s, check.must(store.load(c.s, c.id)), SESSION))
      c.branch = claim.branch(c.id, st.root)
      c.path = fs.join(c.s.root, "wt", c.branch)
      good(c)
      fixture.git(c.path, {"-c", "protocol.file.allow=always", "submodule", "update", "--init", "-q"})
      assert(fs.write(fs.join(c.path, "sub/tracked"), "dirty module"))
      local old = check.must(fs.read(c.file))
      local code, out = run(c, c.path)
      assert(code ~= 0 and out:find("including submodules", 1, true), out)
      assert(check.must(fs.read(c.file)) == old)
    end)
end
