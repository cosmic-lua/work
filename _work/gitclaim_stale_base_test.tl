#!/usr/bin/env cosmic
-- A claim over a product checkout whose local target branch has fallen
-- behind its own fetched remote-tracking ref must never silently capture
-- that stale local value as the claim base (see AGENTS.md's claim/stale
-- target doctrine). It refuses with the exact repair commands, and an
-- explicit --fetch-base authorizes gitboard to run them itself.
local check = require("cosmic.check")
local child = require("cosmic.child")
local claimbatch = require("_work.claimbatch")
local fixture = require("_work.fixture")
local fs = require("cosmic.fs")
local gitclaim_cli = require("_work.gitclaim_cli")
local store = require("_work.store")
local storewrite = require("_work.storewrite")

local CALLER < const > = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

local function git(root: string, args: {string}): string
  local argv: {string} = {"git", "-c", "user.email=test@example.com",
    "-c", "user.name=test"}
  for _, value in ipairs(args) do argv[#argv + 1] = value end
  local r = check.must(child.run(argv, {cwd = root}))
  assert(r.ok, "git " .. table.concat(args, " ") .. " failed: " .. r.stderr)
  return (r.stdout:gsub("%s+$", ""))
end

--- An upstream product repository plus a real clone that tracks it, the
--- shape `git config branch.main.remote`/`.merge` and a `--repo-dir`
--- override both resolve. Upstream then advances past what the clone last
--- fetched, so `checkout`'s local `main` and its own `refs/remotes/origin/
--- main` genuinely disagree once `git fetch` runs inside it.
local function stale_checkout(name: string): string, string, string
  local base = fs.join(fixture.tmpdir, "stale-base-" .. name)
  assert(fs.remove_all(base))
  assert(fs.make_dirs(base))
  local upstream = fs.join(base, "upstream")
  assert(fs.make_dirs(upstream))
  git(upstream, {"init", "-q", "-b", "main"})
  assert(fs.write(fs.join(upstream, "main.txt"), "base\n"))
  git(upstream, {"add", "main.txt"})
  git(upstream, {"commit", "-q", "-m", "base"})
  local old_head = git(upstream, {"rev-parse", "HEAD"})

  local checkout = fs.join(base, "checkout")
  git(base, {"clone", "-q", upstream, checkout})

  assert(fs.write(fs.join(upstream, "main.txt"), "base\nadvanced\n"))
  git(upstream, {"add", "main.txt"})
  git(upstream, {"commit", "-q", "-m", "advance"})
  local new_head = git(upstream, {"rev-parse", "HEAD"})

  git(checkout, {"fetch", "origin"})
  assert(git(checkout, {"rev-parse", "refs/heads/main"}) == old_head,
    "local main must stay put across a plain fetch")
  assert(git(checkout, {"rev-parse", "refs/remotes/origin/main"}) == new_head,
    "the fetch must land the upstream advance in the tracking ref")
  return checkout, old_head, new_head
end

local function claiming_item(name: string): store.Store, string
  local s = fixture.init_state_repo("stale-base-" .. name)
  local _, id = fixture.root_with_leaf(s)
  fixture.give_spec(s, id)
  local it = check.must(store.load(s, id))
  it.repo, it.base = "acme/widgets", "main"
  assert(storewrite.save(s, it, "set product repository"))
  return s, id
end

local function fact(s: store.Store, id: string): claimbatch.Fact
  local it = check.must(store.load(s, id))
  return check.must(claimbatch.read_fact(s.root, it.claim_batch or "", id))
end

local function test_a_locally_stale_target_refuses_instead_of_capturing_it()
  local checkout, old_head = stale_checkout("refuse")
  local s, id = claiming_item("refuse")
  local rc = gitclaim_cli.cmd_claim(s, {id}, "take", CALLER, "origin",
    checkout, false, "", false)
  assert(rc ~= 0, "a claim over a stale local target must not report success")
  assert(git(checkout, {"rev-parse", "refs/heads/main"}) == old_head,
    "a refused claim must never move the checkout's branch itself")
  local it = check.must(store.load(s, id))
  assert((it.claim or "") == "", "the refused claim must not be recorded")
end

local function test_fetch_base_authorizes_the_exact_repair_and_records_it()
  local checkout, _, new_head = stale_checkout("repair")
  local s, id = claiming_item("repair")
  local rc = gitclaim_cli.cmd_claim(s, {id}, "take", CALLER, "origin",
    checkout, false, "", false, true)
  assert(rc == 0, "an explicit --fetch-base must resolve a plain staleness")
  assert(git(checkout, {"rev-parse", "refs/heads/main"}) == new_head,
    "--fetch-base must fast-forward the local branch to what was fetched")
  s = check.must(store.open(s.root))
  assert(fact(s, id).product_base == new_head,
    "the claim base must be the fast-forwarded commit, never the stale one")
end

local function test_an_up_to_date_target_claims_without_fetch_base()
  local checkout = stale_checkout("noop")
  git(checkout, {"pull", "-q", "--ff-only", "origin", "main"})
  local head = git(checkout, {"rev-parse", "refs/heads/main"})
  local s, id = claiming_item("noop")
  local rc = gitclaim_cli.cmd_claim(s, {id}, "take", CALLER, "origin",
    checkout, false, "", false)
  assert(rc == 0, "an already-current target claims normally")
  assert(fact(s, id).product_base == head)
end
