#!/usr/bin/env cosmic
-- A claim over a product checkout whose local target branch has fallen
-- behind its own fetched remote-tracking ref must never silently capture
-- that stale local value as the claim base (see AGENTS.md's claim/stale
-- target doctrine). It refuses with the exact repair commands, and an
-- explicit --fetch-base authorizes gitboard to run them itself.
local check = require("cosmic.check")
local child = require("cosmic.child")
local boardread = require("_work.boardread")
local boardtree = require("_work.boardtree")
local fixture = require("_work.fixture")
local fs = require("cosmic.fs")
local gitclaim_cli = require("_work.gitclaim_cli")
local product = require("_work.product")
local statepublish = require("_work.snapshot_publish")
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

--- The same upstream-plus-clone pair, but nothing has fetched since the
--- clone: local `main` and `refs/remotes/origin/main` agree with each other
--- and are both behind the upstream. `stale_checkout` fetches right after
--- cloning, which lands the advance in the tracking ref and so masks this
--- shape; a session harness supplies exactly this never-fetched clone, and
--- only a fetch inside the claim itself can tell it apart from a current one.
local function unfetched_checkout(name: string): string, string, string
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

  assert(git(checkout, {"rev-parse", "refs/heads/main"}) == old_head)
  assert(git(checkout, {"rev-parse", "refs/remotes/origin/main"}) == old_head,
    "a never-fetched clone's tracking ref must still agree with its branch")
  return checkout, old_head, new_head
end

local function claiming_item(name: string): store.Store, string
  local s = fixture.init_state_repo("stale-base-" .. name)
  local _, id = fixture.root_with_leaf(s)
  fixture.give_spec(s, id)
  local it = check.must(store.load(s, id))
  it.repo, it.base = "acme/widgets", "main"
  assert(storewrite.save(s, it, "set product repository"))
  assert(statepublish.publish(s))
  return s, id
end

local function fact(s: store.Store, id: string): boardtree.Claim
  return check.must(check.must(boardread.load(s.root, s.state_head, id)).claim)
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

local function test_unconfigured_upstream_cannot_silently_capture_stale_base()
  local checkout = stale_checkout("unconfigured")
  git(checkout, {"branch", "--unset-upstream", "main"})
  local s, id = claiming_item("unconfigured")
  local rc = gitclaim_cli.cmd_claim(s, {id}, "take", CALLER, "origin",
    checkout, false, "", false)
  assert(rc ~= 0, "fetched target refs require an explicit upstream before claiming")
end

local function test_missing_configured_tracking_ref_refuses_without_fetch_base()
  local checkout, old_head = stale_checkout("missing-ref-refuse")
  git(checkout, {"update-ref", "-d", "refs/remotes/origin/main"})
  local s, id = claiming_item("missing-ref-refuse")
  assert(gitclaim_cli.cmd_claim(s, {id}, "take", CALLER, "origin",
      checkout, false, "", false) ~= 0,
    "a configured tracking ref that does not resolve cannot be verified offline")
  assert(git(checkout, {"rev-parse", "refs/heads/main"}) == old_head)
  assert((check.must(store.load(s, id)).claim or "") == "")
end

-- A fetch that recreates the missing tracking ref is what --fetch-base is
-- for: the recreated ref is real fetched evidence, verified before the
-- branch moves, not a bypass of the offline refusal above.
local function test_missing_configured_tracking_ref_is_refetched_with_fetch_base()
  local checkout, _, new_head = stale_checkout("missing-ref-fetch")
  git(checkout, {"update-ref", "-d", "refs/remotes/origin/main"})
  local s, id = claiming_item("missing-ref-fetch")
  local rc = gitclaim_cli.cmd_claim(s, {id}, "take", CALLER, "origin",
    checkout, false, "", false, true)
  assert(rc == 0, "--fetch-base must fetch, verify and claim the recreated ref")
  assert(git(checkout, {"rev-parse", "refs/remotes/origin/main"}) == new_head,
    "the fetch must recreate the tracking ref at the upstream tip")
  assert(git(checkout, {"rev-parse", "refs/heads/main"}) == new_head)
  s = check.must(store.open(s.root))
  assert(fact(s, id).product_base == new_head)
end

-- The never-fetched shape: nothing distinguishes it from a current checkout
-- without a network call, and a claim without --fetch-base makes none. That
-- it records the local base is the documented limit of the offline
-- comparison, asserted here so a later change that adds a network call to
-- the default claim is deliberate rather than accidental.
local function test_never_fetched_clone_records_the_local_base_without_fetch_base()
  local checkout, old_head = unfetched_checkout("unfetched-offline")
  local s, id = claiming_item("unfetched-offline")
  local rc = gitclaim_cli.cmd_claim(s, {id}, "take", CALLER, "origin",
    checkout, false, "", false)
  assert(rc == 0, "an offline claim cannot see past the tracking ref as last fetched")
  assert(git(checkout, {"rev-parse", "refs/heads/main"}) == old_head)
  assert(git(checkout, {"rev-parse", "refs/remotes/origin/main"}) == old_head,
    "a claim without --fetch-base must not fetch")
  assert(fact(s, id).product_base == old_head)
end

local function test_never_fetched_clone_is_caught_by_fetch_base()
  local checkout, _, new_head = unfetched_checkout("unfetched-fetch")
  local s, id = claiming_item("unfetched-fetch")
  local rc = gitclaim_cli.cmd_claim(s, {id}, "take", CALLER, "origin",
    checkout, false, "", false, true)
  assert(rc == 0, "--fetch-base must fetch before comparing, then fast-forward")
  assert(git(checkout, {"rev-parse", "refs/remotes/origin/main"}) == new_head,
    "--fetch-base must fetch even when the local branch and tracking ref agree")
  assert(git(checkout, {"rev-parse", "refs/heads/main"}) == new_head,
    "--fetch-base must fast-forward the local branch to the fetched tip")
  s = check.must(store.open(s.root))
  assert(fact(s, id).product_base == new_head,
    "the claim base must be the upstream tip, never the never-fetched one")
end

local function test_truly_local_target_still_claims()
  local checkout, old_head = stale_checkout("local-only")
  git(checkout, {"remote", "remove", "origin"})
  local s, id = claiming_item("local-only")
  assert(gitclaim_cli.cmd_claim(s, {id}, "take", CALLER, "origin",
      checkout, false, "", false) == 0)
  assert(fact(s, id).product_base == old_head)
end

local function test_same_board_product_target_requires_verified_upstream()
  for _, configured in ipairs({false, true}) do
    for _, fetch_base in ipairs({false, true}) do
      local name = "same-board-" .. tostring(configured) .. "-" .. tostring(fetch_base)
      local checkout, old_head, new_head = stale_checkout(name)
      local s, id = claiming_item(name)
      -- The board and product are the SAME checkout, selected by mapping.
      git(s.root, {"remote", "add", "origin", checkout})
      git(s.root, {"fetch", "origin", "refs/remotes/origin/main:refs/remotes/origin/main"})
      git(s.root, {"update-ref", "refs/heads/main", old_head})
      if configured then
        git(s.root, {"branch", "--set-upstream-to=origin/main", "main"})
      end
      -- Keep --fetch-base's explicit fetch at the fetched advanced value.
      git(checkout, {"update-ref", "refs/heads/main", new_head})
      git(s.root, {"config", "--local", "--replace-all", "gitboard.repository",
          product.BOARD_REPO .. "=" .. s.root})
      local it = check.must(store.load(s, id))
      it.repo = product.BOARD_REPO
      assert(storewrite.save(s, it, "use board as product"))
      assert(statepublish.publish(s))
      local rc = gitclaim_cli.cmd_claim(s, {id}, "take", CALLER, "origin",
        "", false, "", false, fetch_base)
      if configured and fetch_base then
        assert(rc == 0)
        assert(fact(s, id).product_base == new_head)
      else
        assert(rc ~= 0, "same-board product must not bypass upstream verification")
        assert((check.must(store.load(s, id)).claim or "") == "")
        assert(git(s.root, {"rev-parse", "refs/heads/main"}) == old_head)
      end
    end
  end
end
