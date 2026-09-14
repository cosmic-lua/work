#!/usr/bin/env cosmic
local check = require("cosmic.check")
local fs = require("cosmic.fs")
local fixture = require("_work.fixture")
local boardread = require("_work.boardread")
local boardtree = require("_work.boardtree")
local stateinit = require("_work.stateinit")
local authority = require("_work.stateclaim_authority")
local store = require("_work.store")
local refs = require("_work.refs")
local gitobj = require("_work.gitobj")
local SESSION < const > = "0123456789abcdef0123456789abcdef"
local function setup(name: string, expires: integer): store.Store, string, string
  local root = fs.join(fixture.tmpdir, "native-authority-" .. name)
  assert(fs.remove_all(root)); assert(fs.make_dirs(root)); assert(stateinit.init(root))
  assert(refs.set_board_mode(root, "local"))
  fixture.git(root, {"checkout", "-q", "state"})
  local head = check.must(refs.read_ref(root, "refs/heads/state"))
  local view = check.must(boardread.list(root, head))
  local id = view.items[1].id
  assert(fs.make_dirs(root .. "/claims"))
  local value: boardtree.Claim = {id = string.rep("a", 40), holder = SESSION,
    acquired_at = expires - 7200, renewed_at = expires - 7200, expires_at = expires, product_base = head}
  assert(fs.write(root .. "/claims/" .. id, check.must(boardtree.encode_claim(value))))
  fixture.git(root, {"add", "claims"}); fixture.git(root, {"commit", "-qm", "acquire fixture"})
  return check.must(store.open(root)), id, check.must(refs.read_ref(root, "refs/heads/state"))
end
local function test_expired_claim_has_no_worktree_authority()
  local s, id = setup("expired", os.time() - 1)
  local got, err = authority.current(s, id, SESSION)
  assert(got == nil and err:find("not active", 1, true))
end
local function test_stale_snapshot_and_historical_receipt_are_not_authority()
  local s, id, old = setup("historical", os.time() + 7200)
  local acquired = check.must(authority.current(s, id, SESSION))
  assert(acquired.root == string.rep("a", 40))
  fixture.git(s.root, {"rm", "-q", "claims/" .. id})
  fixture.git(s.root, {"commit", "-qm", "drop fixture"})
  assert(s.state_head == old)
  local got, err = authority.current(s, id, SESSION)
  assert(got == nil and err ~= "", "a stale Store must not authorize released work")
  assert(store.close(s))
end

local function test_receipt_identity_survives_only_the_same_acquisition()
  local s, id, old = setup("reacquired", os.time() + 7200)
  local previous = check.must(authority.current(s, id, SESSION))
  local value = check.must(boardread.load(s.root, old, id)).claim
  assert(value ~= nil)
  value.id = string.rep("b", 40)
  assert(fs.write(s.root .. "/claims/" .. id, check.must(boardtree.encode_claim(value))))
  fixture.git(s.root, {"add", "claims"}); fixture.git(s.root, {"commit", "-qm", "new acquisition"})
  local current = check.must(authority.current(s, id, SESSION))
  assert(current.holder == previous.holder and current.product_base == previous.product_base)
  assert(authority.historical(s, id, old, current) ~= "", "reacquisition must invalidate the old worktree receipt")
end

local function test_receipt_control_must_be_in_first_parent_history()
  local s, id, old = setup("merge", os.time() + 7200)
  local tree = check.must(gitobj.tree_of(s.root, old))
  local function commit(parents: {string}, message: string): string
    return check.must(gitobj.commit_tree(s.root, {tree = tree, parents = parents,
          message = message, author_name = "test", author_email = "test@example.com",
          committer_name = "test", committer_email = "test@example.com"}))
  end
  local canonical = commit({old}, "canonical continuation")
  local foreign = commit({old}, "foreign control")
  local merge = commit({canonical, foreign}, "merge")
  assert(refs.update_ref(s.root, "refs/heads/state", merge, old))
  local current = check.must(authority.current(s, id, SESSION))
  assert(authority.historical(s, id, canonical, current) == "")
  assert(authority.historical(s, id, foreign, current) ~= "", "second-parent receipt is not canonical authority")
end
