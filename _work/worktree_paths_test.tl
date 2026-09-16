#!/usr/bin/env cosmic
local check = require("cosmic.check")
local child = require("cosmic.child")
local fs = require("cosmic.fs")
local fixture = require("_work.fixture")
local claim = require("_work.claim")
local authority = require("_work.stateclaim_authority")
local store = require("_work.store")
local paths = require("_work.worktree_paths")
local mapping = require("_work.repository_map")
local worktree = require("_work.gitworktree")
local brief = require("_work.brief")
local git = fixture.git

local function value(root: string, args: {string}): string
  local argv = {"git"}
  for _, a in ipairs(args) do argv[#argv + 1] = a end
  local r = check.must(child.run(argv, {cwd = root}))
  assert(r.ok, r.stderr)
  return (r.stdout:gsub("%s+$", ""))
end

local function test_linked_selections_share_primary_placement()
  local base = fs.join(fixture.tmpdir, "worktree-paths")
  assert(fs.remove_all(base) and fs.make_dirs(base))
  local primary = fs.join(base, "product")
  git(base, {"init", "-q", primary})
  git(primary, {"config", "user.name", "test"})
  git(primary, {"config", "user.email", "test@example.com"})
  git(primary, {"commit", "--allow-empty", "-qm", "seed"})
  local head = value(primary, {"rev-parse", "HEAD"})
  assert(fs.write(fs.join(primary, "feature.tl"), ("local x = true\n"):rep(20)))
  git(primary, {"add", "."}); git(primary, {"commit", "-qm", "feature"})
  local handover = value(primary, {"rev-parse", "HEAD"})
  local linked = fs.join(base, "elsewhere", "linked")
  git(primary, {"worktree", "add", "--detach", linked})
  assert(mapping.validate(linked) == linked, "adoption validates actual linked checkout")
  assert(paths.primary(linked) == primary, "registered primary is resolved from linked checkout")
  for n = 1, 3 do
    local s = fixture.init_state_repo("worktree-paths-" .. tostring(n))
    local _, id = fixture.root_with_leaf(s)
    fixture.give_spec(s, id)
    local it = check.must(store.load(s, id))
    it.repo, it.base, it.handover_head = "acme/widgets", head, handover
    fixture.raw_seed_item(s, it, "product facts")
    fixture.claim_item(s, id, "reviewer", head)
    local branch = claim.branch(id, check.must(authority.current(s, id, "reviewer")).root)
    local expected = fs.join(base, "wt", branch)
    local override = ""
    if n == 2 then override = linked
    else assert(mapping.remember(s.root, it.repo, n == 1 and primary or linked)) end
    local previous = fs.cwd()
    assert(fs.set_cwd(linked))
    local code = worktree.cmd_worktree(s, id, "reviewer", override, {}, n == 3, false)
    assert(fs.set_cwd(previous))
    assert(code == 0 and fs.is_dir(expected), "builder/reviewer uses primary sibling destination")
    assert(mapping.resolve(s.root, it.repo, "") == primary)
    if n == 2 then
      assert(value(s.root, {"config", "--get", "gitboard.repository"}) == it.repo .. "=" .. primary,
        "explicit linked override remembers primary")
    end
    local file = fs.join(base, "brief-" .. tostring(n))
    assert(brief.cmd_brief(s, n == 3 and "review" or "builder", id, file) == 0)
    assert(check.must(fs.read(file)):find(expected, 1, true), "brief uses created sibling path")
    assert(worktree.cmd_worktree(s, id, "reviewer", linked, {}, n == 3, false) == 1,
      "existing-worktree check uses same primary path")
  end
  assert(paths.refusal(primary, primary .. "-suffix/new") == nil, "path prefixes are not nesting")
  assert(paths.refusal(primary, primary) ~= nil, "equal worktree is refused")
  local alias = fs.join(base, "alias")
  assert(fs.symlink(linked, alias))
  local refusal = paths.refusal(primary, alias .. "/missing/leaf") or ""
  assert(refusal:find(alias, 1, true) and refusal:find(linked, 1, true),
    "resolved ancestor nesting names destination and registered worktree: " .. refusal)
end

test_linked_selections_share_primary_placement()

local function test_nesting_refuses_before_branch_or_directory_creation()
  local base = fs.join(fixture.tmpdir, "worktree-paths-nested")
  assert(fs.remove_all(base) and fs.make_dirs(base))
  local primary = fs.join(base, "product")
  git(base, {"init", "-q", primary})
  git(primary, {"commit", "--allow-empty", "-qm", "seed"})
  local head = value(primary, {"rev-parse", "HEAD"})
  local conflict = fs.join(base, "wt")
  git(primary, {"worktree", "add", "--detach", conflict})
  for _, reviewing in ipairs({false, true}) do
    local s = fixture.init_state_repo("worktree-nested-" .. tostring(reviewing))
    local _, id = fixture.root_with_leaf(s)
    local it = check.must(store.load(s, id))
    it.repo, it.handover_head = "acme/widgets", head
    fixture.raw_seed_item(s, it, "repo")
    fixture.claim_item(s, id, "reviewer", head)
    local branch = claim.branch(id, check.must(authority.current(s, id, "reviewer")).root)
    local destination = claim.worktree(primary, branch)
    assert(worktree.cmd_worktree(s, id, "reviewer", primary, {}, reviewing, false) == 1)
    assert(not fs.is_present(fs.dirname(destination)), "nesting refusal leaves no directories")
    assert(value(primary, {"branch", "--list", branch}) == "", "nesting refusal leaves no branch")
    local refusal = paths.refusal(primary, destination) or ""
    assert(refusal:find(destination, 1, true) and refusal:find(conflict, 1, true), refusal)
  end
end

test_nesting_refuses_before_branch_or_directory_creation()

local function test_primary_must_be_a_usable_registered_checkout()
  local base = fs.join(fixture.tmpdir, "worktree-primary-unusable")
  assert(fs.remove_all(base) and fs.make_dirs(base))
  local primary = fs.join(base, "product")
  git(base, {"init", "-q", "--separate-git-dir=" .. fs.join(base, "metadata"), primary})
  git(primary, {"commit", "--allow-empty", "-qm", "seed"})
  local linked = fs.join(base, "linked")
  git(primary, {"worktree", "add", "--detach", linked})
  local got, err = paths.primary(linked)
  assert(got == nil and err:find("no usable nonbare primary", 1, true),
    "separate git directory is not guessed to be a checkout: " .. err)
  assert(mapping.validate(linked) == linked)
  local bare = fs.join(base, "bare")
  git(base, {"clone", "--bare", primary, bare})
  local bare_link = fs.join(base, "bare-linked")
  git(bare, {"worktree", "add", "--detach", bare_link})
  got, err = paths.primary(bare_link)
  assert(got == nil and err:find("no usable nonbare primary", 1, true), err)
end

test_primary_must_be_a_usable_registered_checkout()
