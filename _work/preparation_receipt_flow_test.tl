#!/usr/bin/env cosmic
-- Public preparation flows use isolated local Git remotes, never GitHub.
local check = require("cosmic.check")
local child = require("cosmic.child")
local env = require("cosmic.env")
local fs = require("cosmic.fs")
local brief = require("_work.brief")
local claim = require("_work.claim")
local claimcli = require("_work.gitclaim_cli")
local claimsession = require("_work.claimsession")
local fixture = require("_work.fixture")
local gitboard = require("_work.gitboard")
local gitclaim = require("_work.gitclaim")
local gitdraft = require("_work.gitdraft")
local graph = require("_work.gitgraph")
local gitspec = require("_work.gitspec")
local prepared = require("_work.prepared")
local receipt = require("_work.preparation_receipt")
local refs = require("_work.refs")
local store = require("_work.store")
local storewrite = require("_work.storewrite")
local worktree = require("_work.gitworktree")
local git = fixture.git
local SPEC < const > = "## Change\nKeep <BRANCH> and <PREPARATION> literal; café\\t.\n## Non-goals\nNothing else.\n"
local record Case
  s: store.Store
  id: string
  source: string
  base: string
  session: string
  file: string
  path: string
  branch: string
end

local function value(path: string, ...: string): string
  local r = check.must(child.run({"git", ...}, {cwd = path}))
  assert(r.ok, r.stderr)
  return (r.stdout:gsub("%s+$", ""))
end

local function isolated(f: function())
  local keys = {"GIT_AUTHOR_NAME", "GIT_AUTHOR_EMAIL", "GIT_COMMITTER_NAME",
    "GIT_COMMITTER_EMAIL", "GITBOARD_SESSION", "GITBOARD_WORKTREE_BOOTSTRAP", "GITBOARD_DRAFT"}
  local saved: {string: string} = {}
  for _, key in ipairs(keys) do saved[key] = env.get(key); assert(env.unset(key)) end
  local old_print, old_run, old_time = _G.print, child.run, os.time
  local ok, err = pcall(f)
  _G.print, child.run, os.time = old_print, old_run, old_time
  for _, key in ipairs(keys) do
    if saved[key] == nil then assert(env.unset(key)) else assert(env.set(key, saved[key])) end
  end
  if not ok then error(err, 0) end
end

local function capture(f: function(): integer): integer, string
  local old = _G.print
  local lines: {string} = {}
  _G.print = function(...: any)
    local parts: {string} = {}
    for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
    lines[#lines + 1] = table.concat(parts, "\t")
  end
  local ok, code = pcall(f)
  _G.print = old
  if not ok then error(code, 0) end
  return code, table.concat(lines, "\n")
end

local function fresh(name: string, remote: boolean, script?: string): Case
  local s: store.Store
  if remote then
    local other: store.Store
    s, other = fixture.init_shared("receipt-" .. name)
    assert(store.close(other))
  else s = fixture.init_state_repo("receipt-" .. name) end
  local _, id = fixture.root_with_leaf(s)
  local source = fs.join(s.root, "product with spaces")
  assert(fs.make_dirs(fs.join(source, "bin")))
  git(source, {"init", "-q"})
  git(source, {"checkout", "-q", "-b", "main"})
  git(source, {"config", "user.name", "Receipt Fixture"})
  git(source, {"config", "user.email", "receipt@example.test"})
  git(source, {"config", "user.useConfigOnly", "true"})
  assert(fs.write(fs.join(source, "bin/cosmic"), "#!/bin/sh\n" .. (script or "exit 0\n")))
  assert(fs.set_mode(fs.join(source, "bin/cosmic"), tonumber("755", 8)))
  git(source, {"add", "."})
  git(source, {"commit", "-qm", "base"})
  local base = value(source, "rev-parse", "HEAD")
  git(source, {"checkout", "-qb", "source"})
  assert(fs.write(fs.join(source, "ahead"), "source may be ahead"))
  git(source, {"add", "."})
  git(source, {"commit", "-qm", "source ahead"})
  assert(graph.cmd_set(s, id, nil, "acme/receipt", "main") == 0)
  fixture.caller_publish(s)
  local spec = fs.join(s.root, "spec.md")
  assert(fs.write(spec, SPEC))
  assert(gitspec.cmd_spec(s, id, spec) == 0)
  fixture.caller_publish(s)
  git(s.root, {"config", "--add", "gitboard.repository", "acme/receipt=" .. source})
  return {s = s, id = id, source = source, base = base, session = claimsession.mint(),
    file = fs.join(s.root, "receipt.txt"), path = "", branch = ""}
end

local function paths(c: Case, root: string)
  c.branch = claim.branch(c.id, root)
  c.path = fs.join(fs.dirname(c.source), "wt", c.branch)
end

local function acquire(c: Case)
  local code = claimcli.cmd_claim(c.s, {c.id}, "take", c.session, "origin", c.source, false, "", false)
  assert(code == (refs.board_mode(c.s.root) == "local" and 0 or 2))
  fixture.caller_publish(c.s)
  assert(store.close(c.s))
  local it = check.must(store.load(c.s, c.id))
  paths(c, check.must(receipt.active_claim(c.s, it, c.session)).root)
end

local function create(c: Case): integer, string
  return capture(function(): integer
      return gitboard.main("worktree", c.id, "--dir", c.s.root, "--session", c.session,
        "--receipt-out", c.file, "--gitboard-command", "env X='a=b' sh /caller\\tool",
        "--gitboard-cwd", c.s.root)
    end)
end

local function emit(c: Case, session?: string, file?: string, tree?: string): integer, string
  return capture(function(): integer
      return brief.cmd_brief(c.s, "builder", c.id, file, tree, c.file, session or c.session)
    end)
end

local function ready(name: string, remote?: boolean): Case
  local c = fresh(name, remote or false)
  acquire(c)
  local code, out = create(c)
  assert(code == 0, out)
  return c
end

local function test_public_remote_flow_preserves_all_fields_and_spec()
  isolated(function()
      local c = ready("remote", true)
      local bytes = check.must(fs.read(c.file))
      local fields, err = receipt.decode(bytes)
      assert(err == "", err)
      assert(fields.session == c.session and fields.item == c.id)
      assert(fields["board-mode"] == "remote" and fields["board-remote"] == "origin")
      assert(fields.branch == c.branch and fields.worktree == c.path)
      assert(fields["product-root"] == c.source and fields["product-base"] == c.base)
      assert(fields["claim-fact"] == fields["claim-control"])
      assert(fields["gitboard-command"] == "env X='a=b' sh /caller\\tool")
      assert(fields["gitboard-cwd"] == c.s.root)
      local before = value(c.s.root, "show-ref")
      local original = child.run
      child.run = function(argv: {string}, opts?: child.Options): child.Result | nil, string
        if argv[1] == "git" then
          assert(argv[2] ~= "push" and argv[2] ~= "fetch" and argv[2] ~= "update-ref", "read-only receipt")
        end
        return original(argv, opts)
      end
      local code, out = emit(c)
      assert(code == 0, out)
      assert(out:find(bytes, 1, true) ~= nil and out:find(SPEC, 1, true) ~= nil)
      assert(out:find("prepared session " .. c.session, 1, true) ~= nil)
      assert(out:find("claim it as", 1, true) == nil)
      assert(out:find("It is already bootstrapped", 1, true) == nil)
      assert(out:find("not verified", 1, true) ~= nil and out:find("are unverified", 1, true) ~= nil)
      assert(value(c.s.root, "show-ref") == before)
      assert(store.close(c.s))
      local coldcode, coldout = emit(c)
      assert(coldcode == 0 and coldout == out, coldout)
      local output = fs.join(c.s.root, "brief.md")
      assert(gitboard.main("brief", "builder", c.id, "--dir", c.s.root,
          "--receipt", c.file, "--session", c.session, "--out", output, "--tree", c.path) == 0)
      assert(check.must(fs.read(output)):find(SPEC, 1, true) ~= nil)
      assert(store.close(c.s))
    end)
end

local function test_receipt_rejects_mismatched_live_claim_fields()
  isolated(function()
      local c = ready("mismatch")
      local original = check.must(fs.read(c.file))
      local bad: {string: string} = {["board-root"] = "/elsewhere", ["board-mode"] = "remote",
        ["board-remote"] = "other", item = "3J6sZjQEXeXdymAVueHF456JPKE",
        session = ("f"):rep(32), ["claim-fact"] = ("a"):rep(40),
        ["product-base"] = ("b"):rep(40), ["claim-control"] = ("c"):rep(40)}
      for key, v in pairs(bad) do
        local fields = receipt.decode(original)
        fields[key] = v
        if key == "claim-fact" then fields.branch = claim.branch(fields.item, v) end
        if key == "item" then fields.branch = claim.branch(v, fields["claim-fact"]) end
        if key == "board-mode" then fields["board-remote"] = "origin" end
        if key == "board-remote" then fields["board-mode"] = "remote" end
        assert(fs.write(c.file, (receipt.encode(fields))))
        local code, out = emit(c)
        assert(code ~= 0, key .. ": " .. out)
        assert(out:find("You are a builder", 1, true) == nil)
      end
      assert(fs.write(c.file, original))
      assert(emit(c, ("e"):rep(32)) ~= 0)
      assert(store.close(c.s))
    end)
end

local function test_checkout_identity_and_exact_head_are_revalidated()
  isolated(function()
      local c = ready("checkout")
      local bytes = check.must(fs.read(c.file))
      for _, field in ipairs({"worktree", "product-root"}) do
        local fields = receipt.decode(bytes)
        fields[field] = fs.join(c.s.root, "missing")
        assert(fs.write(c.file, (receipt.encode(fields))))
        assert(emit(c) ~= 0, field)
      end
      assert(fs.write(c.file, bytes))
      assert(emit(c, nil, nil, c.source) ~= 0)
      git(c.path, {"checkout", "-q", "--detach"})
      assert(emit(c) ~= 0, "detached checkout")
      git(c.path, {"checkout", "-q", c.branch})
      git(c.path, {"branch", "-m", "wrong-branch"})
      assert(emit(c) ~= 0, "wrong branch")
      git(c.path, {"branch", "-m", c.branch})
      git(c.path, {"commit", "--allow-empty", "-qm", "advanced"})
      assert(emit(c) ~= 0, "advanced HEAD must refuse")
      assert(store.close(c.s))
    end)
end

local function test_confirmed_renewal_preserves_receipt_but_reacquisition_does_not()
  isolated(function()
      local c = ready("renew", true)
      local bytes = check.must(fs.read(c.file))
      local first = receipt.decode(bytes)
      local now = os.time()
      os.time = function(): integer return now + 1 end
      fixture.control_claim(c.s, {c.id}, c.session, "renew")
      local code, out = emit(c)
      assert(code == 0 and out:find(bytes, 1, true) ~= nil, out)
      local it = check.must(store.load(c.s, c.id))
      assert(it.claim_batch ~= first["claim-control"])
      os.time = function(): integer return now + claim.LEASE_S + 2 end
      assert(emit(c) ~= 0, "expired receipt")
      os.time = function(): integer return now + 2 end
      fixture.drop_claim(c.s, c.id, c.session, "new acquisition")
      assert(emit(c) ~= 0, "dropped receipt")
      fixture.claim_item(c.s, c.id, c.session, c.base)
      assert(emit(c) ~= 0, "same holder, different acquisition")
      assert(store.close(c.s))
    end)
end

local function test_local_receipt_rework_and_legacy_compatibility()
  isolated(function()
      local c = fresh("rework", false)
      local it = check.must(store.load(c.s, c.id))
      it.verdict, it.verdict_head = "request changes", c.base
      assert(storewrite.save(c.s, it, "fixture request changes"))
      acquire(c)
      assert(create(c) == 0)
      local fields = receipt.decode(check.must(fs.read(c.file)))
      assert(fields["board-mode"] == "local" and fields["board-remote"] == "")
      local code, out = emit(c)
      assert(code == 0, out)
      assert(out:find("repair on " .. string.char(96) .. c.branch, 1, true) ~= nil, out)
      assert(out:find("branch " .. string.char(96) .. c.id:sub(1, 8), 1, true) == nil)
      local legacy, text = capture(function(): integer return brief.cmd_brief(c.s, "builder", c.id) end)
      assert(legacy == 0 and text:find("claimed under session " .. c.session, 1, true) ~= nil)
      assert(text:find("It is already bootstrapped", 1, true) ~= nil)
      assert(store.close(c.s))
    end)
end

local function test_receipt_option_failures_and_explicit_skip()
  isolated(function()
      local c = fresh("options", false, "exit 17\n")
      acquire(c)
      for _, kind in ipairs({"review", "research", "refine", "decompose"}) do
        assert(capture(function(): integer
              return brief.cmd_brief(c.s, kind, c.id, nil, nil, c.file, c.session)
            end) ~= 0)
      end
      for _, args in ipairs({{"-", "", ""}, {c.file, "only-command", ""},
          {c.file, "bad\ncommand", c.s.root}, {c.file, "command", "/absent"}}) do
        assert(worktree.cmd_worktree(c.s, c.id, c.session, c.source, {}, false, false,
            args[1], args[2], args[3]) ~= 0)
      end
      assert(worktree.cmd_worktree(c.s, c.id, c.session, c.source, {}, true, false, c.file) ~= 0)
      assert(not fs.is_dir(c.path))
      assert(env.set("GITBOARD_WORKTREE_BOOTSTRAP", "0"))
      local code, out = capture(function(): integer
          return worktree.cmd_worktree(c.s, c.id, c.session, c.source, {}, false, false, c.file)
        end)
      assert(code == 0, out)
      local fields = receipt.decode(check.must(fs.read(c.file)))
      assert(fields.bootstrap == "cosmic (skipped: GITBOARD_WORKTREE_BOOTSTRAP=0)")
      assert(fields["gitboard-command"] == "" and fields["gitboard-cwd"] == "")
      assert(emit(c) == 0)
      assert(env.set("GITBOARD_SESSION", c.session))
      assert(gitboard.main("brief", "builder", c.id, "--dir", c.s.root, "--receipt", c.file) == 0)
      assert(env.unset("GITBOARD_SESSION"))
      assert(fs.write(c.file, "not a receipt\n"))
      local output = fs.join(c.s.root, "should-not-write")
      assert(emit(c, nil, output) ~= 0 and not fs.is_file(output))
      assert(store.close(c.s))
    end)
end

local function test_active_draft_refuses_before_creation_and_before_brief_output()
  isolated(function()
      local c = fresh("draft", false)
      acquire(c)
      local d = check.must(gitdraft.begin(c.s.root))
      assert(env.set("GITBOARD_DRAFT", d.id))
      local code, out = create(c)
      assert(code ~= 0 and not fs.is_dir(c.path), out)
      assert(env.unset("GITBOARD_DRAFT"))
      gitdraft.deactivate(c.s.root)
      assert(store.close(c.s))
      assert(create(c) == 0)
      assert(env.set("GITBOARD_DRAFT", d.id))
      local output = fs.join(c.s.root, "draft-brief.md")
      code, out = capture(function(): integer
          return gitboard.main("brief", "builder", c.id, "--dir", c.s.root,
            "--receipt", c.file, "--session", c.session, "--out", output)
        end)
      assert(code ~= 0 and not fs.is_file(output), out)
      gitdraft.deactivate(c.s.root)
      assert(store.close(c.s))
    end)
end

local function test_unrelated_checkout_cannot_substitute_identical_head_and_branch()
  isolated(function()
      local c = ready("unrelated")
      local clone = fs.join(c.s.root, "unrelated")
      git(c.s.root, {"clone", "-q", c.source, clone})
      git(clone, {"checkout", "-q", "-b", c.branch, c.base})
      local fields = receipt.decode(check.must(fs.read(c.file)))
      fields.worktree = clone
      assert(fs.write(c.file, (receipt.encode(fields))))
      local code, out = emit(c)
      assert(code ~= 0 and out:find("repository mismatch", 1, true) ~= nil, out)
      fields.worktree = fs.join(c.path, "bin")
      assert(fs.write(c.file, (receipt.encode(fields))))
      assert(emit(c) ~= 0, "nested directory is not a checkout root")
      assert(store.close(c.s))
    end)
end

local function test_bootstrap_and_receipt_write_failures_preserve_checkout()
  for _, failed_bootstrap in ipairs({false, true}) do
    isolated(function()
        local c = fresh("write-" .. tostring(failed_bootstrap), false, failed_bootstrap and "exit 17\n" or nil)
        acquire(c)
        if not failed_bootstrap then c.file = fs.join(c.s.root, "absent-parent", "receipt") end
        local code, out = create(c)
        assert(code ~= 0 and fs.is_dir(c.path), out)
        assert(out:find("checkout created at " .. c.path .. "; preparation failed:", 1, true) ~= nil)
        assert(not fs.is_file(c.file))
        assert(store.close(c.s))
      end)
  end
end

local function test_unconfirmed_partial_and_staged_batches_refuse_preparation()
  isolated(function()
      local c = fresh("partial", true)
      local peer = fixture.file_item(c.s, "other member", "")
      local reqs: {gitclaim.Request} = {}
      for _, id in ipairs({c.id, peer}) do
        reqs[#reqs + 1] = {root = c.s.root, id = id, source_ref = gitclaim.remote_item_ref("origin", id),
          target_ref = gitclaim.target_item_ref(id), remote = "origin", batch = claimsession.mint(),
          caller = c.session, action = "take", product_base = c.base, force = false, why = "", now = os.time()}
      end
      reqs[2].batch = reqs[1].batch
      local p = check.must(gitclaim.prepare_batch(reqs).prepared)
      paths(c, p.batch.commit)
      assert(create(c) ~= 0 and not fs.is_dir(c.path), "unconfirmed preparation")
      for _, update in ipairs(p.transaction.updates) do
        if update.ref ~= gitclaim.target_item_ref(peer) then
          git(c.s.root, {"update-ref", check.must(refs.tracking_ref(update.ref)), update.next})
        end
      end
      assert(store.close(c.s))
      assert(create(c) ~= 0 and not fs.is_dir(c.path), "partial multi-member confirmation")
      for _, update in ipairs(p.transaction.updates) do
        git(c.s.root, {"update-ref", check.must(refs.tracking_ref(update.ref)), update.next})
      end
      assert(store.close(c.s))
      local code, out = create(c)
      assert(code ~= 0 and out:find("confirmation pending", 1, true) ~= nil, out)
      assert(not fs.is_dir(c.path))
      assert(check.must(prepared.refresh(c.s.root))[1].state == "confirmed")
      assert(create(c) == 0)
      refs.set_overlay(c.s.root, {})
      local denied = emit(c)
      refs.clear_overlay(c.s.root)
      assert(denied ~= 0, "overlay cannot validate receipts")
      assert(store.close(c.s))
    end)
end
