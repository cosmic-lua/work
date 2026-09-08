#!/usr/bin/env cosmic
-- V3 handover tests. A `take` records one locally inspectable product
-- commit; provider state, PR numbers, CI observations and credentials are
-- deliberately absent from this boundary.

local check = require("cosmic.check")
local child = require("cosmic.child")
local fixture = require("_work.fixture")
local fs = require("cosmic.fs")
local gittake = require("_work.gittake")
local store = require("_work.store")
local storewrite = require("_work.storewrite")

local tmpdir = os.getenv("TEST_TMPDIR") or "/tmp"
local BUILDER < const > = "0123456789abcdef0123456789abcdef"
local STRANGER < const > = "fedcba9876543210fedcba9876543210"

local function git(root: string, args: {string}): string
  local argv: {string} = {"git", "-c", "user.email=test@example.com",
    "-c", "user.name=test"}
  for _, value in ipairs(args) do argv[#argv + 1] = value end
  local r = check.must(child.run(argv, {cwd = root}))
  assert(r.ok, "git " .. table.concat(args, " ") .. " failed: " .. r.stderr)
  return (r.stdout:gsub("%s+$", ""))
end

local function product(name: string): string, string, string, string
  local root = fs.join(tmpdir, "gittake-v3-" .. name)
  assert(fs.remove_all(root))
  assert(fs.make_dirs(root))
  git(root, {"init", "-q"})
  git(root, {"checkout", "-q", "-b", "main"})
  assert(fs.write(fs.join(root, "file"), "base\n"))
  git(root, {"add", "file"})
  git(root, {"commit", "-q", "-m", "base"})
  local base = git(root, {"rev-parse", "HEAD"})
  git(root, {"checkout", "-q", "-b", "work"})
  assert(fs.write(fs.join(root, "file"), "base\none\n"))
  git(root, {"commit", "-q", "-am", "one"})
  local first = git(root, {"rev-parse", "HEAD"})
  assert(fs.write(fs.join(root, "file"), "base\none\ntwo\n"))
  git(root, {"commit", "-q", "-am", "two"})
  return root, base, first, git(root, {"rev-parse", "HEAD"})
end

local function claimed(name: string, base: string): store.Store, string
  local s = fixture.init_state_repo("gittake-v3-" .. name)
  local _parent, id = fixture.root_with_leaf(s)
  fixture.give_spec(s, id)
  local it = check.must(store.load(s, id))
  it.repo = "acme/widgets"
  it.claim = BUILDER
  it.claim_base = base
  assert(storewrite.save(s, it,
      ("claim acquire %s by %s"):format(id:sub(1, 8), BUILDER)))
  return s, id
end

local function test_handover_records_only_the_exact_commit_and_navigation_url()
  local repo, base, head = product("record")
  local s, id = claimed("record", base)
  local it = check.must(store.load(s, id))
  assert(#it.builders == 0, "acquisition alone is not builder involvement")
  assert(gittake.take_handover(s, it, BUILDER, head:sub(1, 12),
      "https://example.test/change/7", repo) == 0)
  local got = check.must(store.load(s, id))
  assert(got.handover_head == head, "an abbreviation canonicalizes to full SHA")
  assert(got.external_url == "https://example.test/change/7")
  assert(got.claim == BUILDER, "a workflow transition never releases the claim")
  assert(#got.builders == 1 and got.builders[1] == BUILDER,
    "the builder is attributed at handover")
  assert(got.pr == 0 and got.result == "",
    "no provider or synthetic evidence is recorded")
end

local function test_handover_requires_the_holder_and_a_descendant_commit()
  local repo, base, head = product("guards")
  local s, id = claimed("guards", base)
  local it = check.must(store.load(s, id))
  assert(gittake.take_handover(s, it, STRANGER, head, "", repo) ~= 0,
    "a caller cannot hand over somebody else's claim")
  assert(check.must(store.load(s, id)).handover_head == "")

  it = check.must(store.load(s, id))
  assert(gittake.take_handover(s, it, BUILDER, ("f"):rep(40), "", repo) ~= 0,
    "the evidence commit has to exist locally")
  assert(check.must(store.load(s, id)).handover_head == "")

  it = check.must(store.load(s, id))
  assert(gittake.take_handover(s, it, BUILDER, head,
      "github:acme/widgets#7", repo) ~= 0,
    "navigation metadata is one ordinary http(s) URL")
  assert(check.must(store.load(s, id)).handover_head == "")
end

local function test_rework_handover_replaces_the_commit_not_the_claim()
  local repo, base, first, second = product("rework")
  local s, id = claimed("rework", base)
  local it = check.must(store.load(s, id))
  assert(gittake.take_handover(s, it, BUILDER, first, "", repo) == 0)
  it = check.must(store.load(s, id))
  it.verdict = "request changes"
  it.verdict_head = first
  assert(storewrite.save(s, it, "fixture: request changes"))
  it = check.must(store.load(s, id))
  assert(gittake.take_handover(s, it, BUILDER, second, "", repo) == 0)
  local got = check.must(store.load(s, id))
  assert(got.handover_head == second and got.verdict == ""
    and got.verdict_head == "", "a new commit consumes the prior send-back")
  assert(got.claim == BUILDER, "rework keeps the same explicit lease")
  assert(#got.builders == 1, "re-handover does not duplicate involvement")
end
