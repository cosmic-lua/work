--- Hermetic product/board fixture for commit-only handover and review tests.
local check = require("cosmic.check")
local child = require("cosmic.child")
local fixture = require("_work.fixture")
local fs = require("cosmic.fs")
local gitclaim_cli = require("_work.gitclaim_cli")
local gittake = require("_work.gittake")
local store = require("_work.store")
local storewrite = require("_work.storewrite")

local BUILDER < const > = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
local REVIEWER < const > = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
local LANDER < const > = "cccccccccccccccccccccccccccccccc"
local OTHER < const > = "dddddddddddddddddddddddddddddddd"

local record Product
  root: string
  base: string
  head: string
  next_head: string
  squash: string
  mismatch: string
  unrelated: string
end

local function git(root: string, args: {string}, stdin?: string): string
  local argv: {string} = {"git", "-c", "user.email=test@example.com",
    "-c", "user.name=test"}
  for _, value in ipairs(args) do argv[#argv + 1] = value end
  local r = check.must(child.run(argv, {cwd = root, stdin = stdin or ""}))
  assert(r.ok, "git " .. table.concat(args, " ") .. " failed: " .. r.stderr)
  return (r.stdout:gsub("%s+$", ""))
end

local function product(name: string): Product
  local root = fs.join(fixture.tmpdir, "commit-flow-" .. name)
  assert(fs.remove_all(root))
  assert(fs.make_dirs(root))
  git(root, {"init", "-q"})
  git(root, {"checkout", "-q", "-b", "main"})
  assert(fs.write(fs.join(root, "base.txt"), "base\n"))
  git(root, {"add", "base.txt"})
  git(root, {"commit", "-q", "-m", "base"})
  local base = git(root, {"rev-parse", "HEAD"})

  git(root, {"checkout", "-q", "-b", "work"})
  assert(fs.write(fs.join(root, "feature.txt"), "one\n"))
  git(root, {"add", "feature.txt"})
  git(root, {"commit", "-q", "-m", "feature one"})
  local head = git(root, {"rev-parse", "HEAD"})
  assert(fs.write(fs.join(root, "feature.txt"), "one\ntwo\n"))
  git(root, {"commit", "-q", "-am", "feature two"})
  local next_head = git(root, {"rev-parse", "HEAD"})

  git(root, {"checkout", "-q", "-b", "squash", base})
  assert(fs.write(fs.join(root, "feature.txt"), "one\ntwo\n"))
  git(root, {"add", "feature.txt"})
  git(root, {"commit", "-q", "-m", "squash feature"})
  local squash = git(root, {"rev-parse", "HEAD"})

  git(root, {"checkout", "-q", "-b", "mismatch", base})
  assert(fs.write(fs.join(root, "feature.txt"), "wrong\n"))
  git(root, {"add", "feature.txt"})
  git(root, {"commit", "-q", "-m", "different feature"})
  local mismatch = git(root, {"rev-parse", "HEAD"})

  git(root, {"checkout", "-q", "--orphan", "unrelated"})
  git(root, {"rm", "-q", "-rf", "."})
  assert(fs.write(fs.join(root, "other.txt"), "unrelated\n"))
  git(root, {"add", "other.txt"})
  git(root, {"commit", "-q", "-m", "unrelated root"})
  local unrelated = git(root, {"rev-parse", "HEAD"})
  return {root = root, base = base, head = head, next_head = next_head,
    squash = squash, mismatch = mismatch, unrelated = unrelated}
end

local function fresh(name: string): store.Store, string, Product
  local p = product(name)
  local s = fixture.init_state_repo("commit-flow-" .. name)
  local _, id = fixture.root_with_leaf(s)
  fixture.give_spec(s, id)
  local it = check.must(store.load(s, id))
  it.repo = "acme/widgets"
  it.base = "main"
  assert(storewrite.save(s, it, "set product repository"))
  return s, id, p
end

local function claim(s: store.Store, id: string, session: string,
    p: Product, action?: string, force?: boolean, why?: string): integer
  return gitclaim_cli.cmd_claim(s, {id}, action == "drop" and "drop"
    or action == "renew" and "renew" or "take", session, "origin", p.root,
    force or false, why or "", false)
end

local function handover(s: store.Store, id: string, session: string,
    p: Product, head: string, url?: string): integer
  return gittake.take_handover(s, check.must(store.load(s, id)), session,
    head, url or "", p.root)
end

local record commit_flow_fixture
  type Product = Product
  BUILDER: string
  REVIEWER: string
  LANDER: string
  OTHER: string
  product: function(name: string): Product
  fresh: function(name: string): store.Store, string, Product
  claim: function(s: store.Store, id: string, session: string,
  p: Product, action?: string, force?: boolean, why?: string): integer
  handover: function(s: store.Store, id: string, session: string,
  p: Product, head: string, url?: string): integer
end

local M: commit_flow_fixture = {
  BUILDER = BUILDER, REVIEWER = REVIEWER, LANDER = LANDER, OTHER = OTHER,
  product = product, fresh = fresh, claim = claim, handover = handover,
}
return M
