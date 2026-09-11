#!/usr/bin/env cosmic
-- The narrow commit-only integration: a handover canonicalizes a locally
-- present product commit, verdict records that exact commit, and done verifies
-- and records a squash landing. No remote or provider object exists.
local check = require("cosmic.check")
local child = require("cosmic.child")
local claimbatch = require("_work.claimbatch")
local fixture = require("_work.fixture")
local fs = require("cosmic.fs")
local gate = require("_work.gitgate")
local gitclaim = require("_work.gitclaim")
local gitdone = require("_work.gitdone")
local gittake = require("_work.gittake")
local gitverdict = require("_work.gitverdict")
local prepared = require("_work.prepared")
local store = require("_work.store")
local storewrite = require("_work.storewrite")

local tmpdir = os.getenv("TEST_TMPDIR") or "/tmp"

local function git(root: string, args: {string}, stdin?: string): string
  local argv: {string} = {"git", "-c", "user.email=test@example.com",
    "-c", "user.name=test"}
  for _, value in ipairs(args) do argv[#argv + 1] = value end
  local r = check.must(child.run(argv, {cwd = root, stdin = stdin or ""}))
  assert(r.ok, "git " .. table.concat(args, " ") .. " failed: " .. r.stderr)
  return (r.stdout:gsub("%s+$", ""))
end

local function product(): string, string, string, string
  local root = fs.join(tmpdir, "gitcommitflow-product")
  assert(fs.remove_all(root))
  assert(fs.make_dirs(root))
  git(root, {"init", "-q"})
  git(root, {"checkout", "-q", "-b", "main"})
  assert(fs.write(fs.join(root, "file"), "base\n"))
  git(root, {"add", "file"})
  git(root, {"commit", "-q", "-m", "base"})
  local base = git(root, {"rev-parse", "HEAD"})
  git(root, {"checkout", "-q", "-b", "work"})
  assert(fs.write(fs.join(root, "file"), "base\nchange\n"))
  git(root, {"commit", "-q", "-am", "change"})
  local head = git(root, {"rev-parse", "HEAD"})
  git(root, {"checkout", "-q", "main"})
  local diff = check.must(child.run({"git", "diff", "--binary", base, head},
      {cwd = root}))
  assert(diff.ok, diff.stderr)
  local apply = check.must(child.run({"git", "apply", "--index"},
      {cwd = root, stdin = diff.stdout}))
  assert(apply.ok, apply.stderr)
  git(root, {"commit", "-q", "-m", "squash"})
  return root, base, head, git(root, {"rev-parse", "HEAD"})
end

local function claim_action(s: store.Store, id: string, caller: string,
    action: gitclaim.Action, product_base: string)
  local target = gitclaim.target_item_ref(id)
  local result = gitclaim.prepare_batch({{
        root = s.root, id = id, source_ref = target, target_ref = target,
        remote = "origin", batch = action .. "-" .. caller .. "-" .. id:sub(-8),
        caller = caller, action = action, product_base = product_base,
        force = false, why = "", now = os.time(),
      }})
  assert(result.prepared ~= nil, result.refused[id] or result.refused.batch)
  assert(prepared.promote_local(s.root, result.prepared.transaction))
end

local function test_commit_only_flow()
  local product_root, base, head, landed = product()
  local s = fixture.init_state_repo("commit-flow")
  local _, leaf = fixture.root_with_leaf(s)
  fixture.give_spec(s, leaf)
  local it = check.must(store.load(s, leaf))
  it.repo = "acme/widgets"
  assert(storewrite.save(s, it, "set product repository"))
  claim_action(s, leaf, "run-a", "take", base)
  assert(#check.must(store.load(s, leaf)).builders == 0,
    "claim acquisition does not attribute a builder")

  it = check.must(store.load(s, leaf))
  assert(gittake.take_handover(s, it, "run-a", head:sub(1, 12),
      "https://example.test/change/7", product_root) == 0)
  local handed = check.must(store.load(s, leaf))
  assert(handed.handover_head == head, "handover stores the full commit id")
  assert(handed.external_url == "https://example.test/change/7")
  assert(#handed.builders == 1 and handed.builders[1] == "run-a",
    "the builder is recorded at handover, not claim acquisition")
  assert(handed.claim == "run-a", "handover never releases the claim")

  -- Review is a distinct caller and therefore a distinct claim. The builder
  -- explicitly releases; neither handover nor any later transition does it.
  claim_action(s, leaf, "run-a", "drop", "")
  local reviewing = check.must(store.load(s, leaf))
  assert(reviewing.handover_head == head,
    "explicit claim release preserves the workflow evidence")
  claim_action(s, leaf, "run-b", "take", base)
  reviewing = check.must(store.load(s, leaf))
  local review_claim = check.must(claimbatch.read_state(s.root,
      reviewing.claim_batch or "", leaf))

  assert(gitverdict.cmd_verdict_commit(s, leaf, "accept", head, "run-b",
      false, "", product_root) == 0)
  local accepted = check.must(store.load(s, leaf))
  assert(accepted.verdict == "accept" and accepted.verdict_head == head)
  assert((accepted.handover_head or "") == head,
    "verdict preserves the commit handover")
  assert(accepted.claim == "run-b", "verdict does not release the claim")

  assert(gitdone.cmd_done(s, leaf, "completed", false, "", "", landed,
      product_root, "run-b") == 0)
  local completed = check.must(store.load(s, leaf))
  assert(completed.resolution == "completed" and completed.landed_head == landed)
  assert(completed.claim == "run-b", "done does not release the claim")
  assert(completed.external_url == "https://example.test/change/7",
    "the navigation URL remains metadata only")

  completed.title = "foreign rewrite"
  local foreign, ferr = gate.commit_and_publish(s, completed, nil,
    "set title", "set", nil, "run-c")
  assert(not foreign and ferr:find("frozen by run-b", 1, true) ~= nil,
    "a live whole-item claim freezes every mutation: " .. tostring(ferr))

  completed = check.must(store.load(s, leaf))
  completed.title = "holder rewrite"
  local own, oerr = gate.commit_and_publish(s, completed, nil,
    "set title", "set", nil, "run-b")
  assert(own, oerr)
  completed = check.must(store.load(s, leaf))
  local after_claim = check.must(claimbatch.read_state(s.root,
      completed.claim_batch or "", leaf))
  assert(after_claim.control == review_claim.control
    and after_claim.expires_at == review_claim.expires_at,
    "an ordinary holder mutation must not renew the lease")

  completed.title = "audited repair"
  local repaired, rerr = gate.commit_and_publish(s, completed, nil,
    "set title (forced: repair)", "set", nil, "run-c", false, true,
    "repair")
  assert(repaired, rerr)
end
test_commit_only_flow()

--- `--force --landed` is an audited repair, never a silent bypass: an
--- unverified landed commit still refuses without it, and force must
--- retain the exact commit the caller explicitly vouches for rather than
--- requiring `--landed` to be dropped to complete at all.
local function test_force_landed_retains_a_verified_but_unmatching_commit()
  local product_root, base, head = product()
  local s = fixture.init_state_repo("commit-flow-force-landed")
  local _, leaf = fixture.root_with_leaf(s)
  fixture.give_spec(s, leaf)
  local it = check.must(store.load(s, leaf))
  it.repo = "acme/widgets"
  assert(storewrite.save(s, it, "set product repository"))
  claim_action(s, leaf, "run-a", "take", base)
  it = check.must(store.load(s, leaf))
  assert(gittake.take_handover(s, it, "run-a", head, "", product_root) == 0)
  claim_action(s, leaf, "run-a", "drop", "")
  claim_action(s, leaf, "run-b", "take", base)
  assert(gitverdict.cmd_verdict_commit(s, leaf, "accept", head, "run-b",
      false, "", product_root) == 0)

  -- A commit that shares only the claim base with the accepted change —
  -- automatic ancestry/content verification must refuse it outright.
  git(product_root, {"checkout", "-q", "-b", "elsewhere", base})
  assert(fs.write(fs.join(product_root, "file"), "not the accepted change\n"))
  git(product_root, {"commit", "-q", "-am", "unrelated landing"})
  local mismatched = git(product_root, {"rev-parse", "HEAD"})

  assert(gitdone.cmd_done(s, leaf, "completed", false, "", "", mismatched,
      product_root, "run-b") ~= 0,
    "an unverified landed commit must never land without --force")

  assert(gitdone.cmd_done(s, leaf, "completed", true,
      "manually confirmed equivalent outside gitboard", "", mismatched,
      product_root, "run-b") == 0,
    "an audited --force --landed repair must retain the exact commit named")
  local completed = check.must(store.load(s, leaf))
  assert(completed.landed_head == mismatched,
    "force must record the real landed commit, never discard it")
end
test_force_landed_retains_a_verified_but_unmatching_commit()
