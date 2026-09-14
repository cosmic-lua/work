local check = require("cosmic.check")
local fs = require("cosmic.fs")
local child = require("cosmic.child")
local fixture = require("_work.fixture")
local claimcli = require("_work.gitclaim_cli")
local init = require("_work.stateinit")
local refs = require("_work.refs")
local store = require("_work.store")
local native = require("_work.stateclaim_authority")
local claim = require("_work.claim")
local receipt = require("_work.preparation_receipt")
local workspace = require("_work.snapshot_workspace")
local staging = require("_work.statestaging")
local boardread = require("_work.boardread")

-- `claim` is mutual exclusion, so it may reserve an unranked item whose spec
-- is still empty. The readiness and workability recheck belongs to `take`.
local function test_direct_claim_is_exclusion_only()
  local s = fixture.init_state_repo("native-direct-claim")
  local id = fixture.file_item(s, "Unranked and unspecced", "")
  local prose = store.read_spec(s, id)
  assert(prose.change == "" and prose.non_goals == "")
  local who = "0123456789abcdef0123456789abcdef"
  assert(claimcli.cmd_claim(s, {id}, "take", who, "origin", "", false,
      "", false) == 0)
  assert(check.must(store.load(s, id)).claim == who)
end

local function test_native_cli_claim_worktree_and_release()
  local root = fs.join(fixture.tmpdir, "native-cli-lifecycle")
  assert(fs.remove_all(root)); assert(fs.make_dirs(root)); assert(init.init(root)); assert(refs.set_board_mode(root, "local"))
  local function cli(args: {string}, expected?: integer): string
    local argv: {string} = {"o/bin/gitboard"}
    for _, a in ipairs(args) do argv[#argv + 1] = a end
    argv[#argv + 1] = "--dir"; argv[#argv + 1] = root
    local r = check.must(child.run(argv, {cwd = "."}))
    assert(r.code == (expected or 0), r.stdout .. r.stderr); return r.stdout
  end
  cli({"new", "native task"})
  local s = check.must(store.open(root)); local all = check.must(store.list(s)); local id = ""
  for _, it in ipairs(all) do if it.title == "native task" then id = it.id end end
  assert(id ~= ""); assert(store.close(s))
  local who = "0123456789abcdef0123456789abcdef"
  local product = root .. "/product"
  assert(fs.make_dirs(product)); fixture.git(product, {"init", "-q", "-b", "main"})
  assert(fs.write(product .. "/README", "native product\n")); fixture.git(product, {"add", "."}); fixture.git(product, {"commit", "-qm", "base"})
  fixture.git(product, {"config", "user.name", "test"}); fixture.git(product, {"config", "user.email", "test@example.com"})
  cli({"set", id, "--repo", "test/product"})
  cli({"claim", id, "--session", who, "--repo-dir", product})
  local authority = check.must(native.current(check.must(store.open(root)), id, who))
  cli({"worktree", id, "--session", who, "--repo-dir", product, "--receipt-out", root .. "/builder.receipt"})
  assert(fs.is_dir(claim.worktree(product, claim.branch(id, authority.root))))
  cli({"refresh"})
  cli({"set", id, "--title", "native changed", "--session", who})
  cli({"renew", id, "--session", who})
  local renewed_store = check.must(store.open(root))
  local renewed_item = check.must(store.load(renewed_store, id))
  local values, receipt_err = receipt.read(renewed_store, renewed_item, "builder", root .. "/builder.receipt", who, "")
  assert(receipt_err == "", receipt_err); assert(values["claim-fact"] == authority.root)
  assert(store.close(renewed_store))
  cli({"drop", id, "--session", who, "--why", "done"})
  local stale, stale_err = native.current(check.must(store.open(root)), id, who)
  assert(stale == nil and stale_err ~= "")
  local head = check.must(refs.read_ref(root, "refs/heads/state")); assert(check.must(boardread.list(root, head)).claims_by_id[id] == nil)
  local released = check.must(child.run({"git", "-C", root, "show", "-s", "--format=%B", head}))
  assert(released.ok and released.stdout:match("^drop by ") ~= nil, released.stdout)
  assert(released.stdout:find("Drop-Why: done", 1, true) ~= nil, released.stdout)
end

local function test_native_remote_claim_publication()
  local root = fs.join(fixture.tmpdir, "native-cli-remote")
  assert(fs.remove_all(root)); assert(fs.make_dirs(root)); assert(init.init(root)); assert(refs.set_board_mode(root, "local"))
  local function cli(args: {string}, expected?: integer): string
    local argv: {string} = {"o/bin/gitboard"}
    for _, a in ipairs(args) do argv[#argv + 1] = a end
    argv[#argv + 1] = "--dir"; argv[#argv + 1] = root
    local r = check.must(child.run(argv, {cwd = "."}))
    assert(r.code == (expected or 0), r.stdout .. r.stderr); return r.stdout
  end
  cli({"new", "native task"})
  local s = check.must(store.open(root)); local all = check.must(store.list(s)); local id = ""
  for _, it in ipairs(all) do if it.title == "native task" then id = it.id end end
  assert(id ~= ""); assert(store.close(s))
  fixture.git(root, {"symbolic-ref", "HEAD", "refs/heads/state"})
  local bare = root .. "/remote.git"; local client = root .. "/client"
  fixture.git(root, {"clone", "-q", "--bare", root, bare}); fixture.git(root, {"clone", "-q", bare, client})
  root = client
  assert(refs.set_board_mode(root, "remote"))
  local function publish_pending()
    local pending = check.must(workspace.read(root))
    cli({"publish", pending.commit})
    cli({"refresh"})
  end
  local who = "0123456789abcdef0123456789abcdef"
  cli({"claim", id, "--session", who}, 2)
  assert(native.current(check.must(store.open(root)), id, who) == nil)
  publish_pending()

  local claimed = check.must(boardread.list(root,
      check.must(refs.read_ref(root, "refs/remotes/origin/state"))))
  local renewed_at = claimed.claims_by_id[id].renewed_at
  while os.time() <= renewed_at do end
  cli({"renew", id, "--session", who}, 2)
  publish_pending()
  cli({"drop", id, "--session", who, "--why", "done"}, 2)
  publish_pending()
  local head = check.must(refs.read_ref(root, "refs/remotes/origin/state")); assert(check.must(boardread.list(root, head)).claims_by_id[id] == nil)

end

local function test_mixed_self_overlap_rejects_the_complete_cli_acquisition()
  local s = fixture.init_state_repo("native-self-overlap")
  local first = fixture.file_item(s, "Already held", "")
  local second = fixture.file_item(s, "Still free", "")
  local who = "0123456789abcdef0123456789abcdef"
  local function cli(ids: {string}, expected: integer): string
    local argv = {"o/bin/gitboard", "claim"}
    for _, id in ipairs(ids) do argv[#argv + 1] = id end
    argv[#argv + 1] = "--session"; argv[#argv + 1] = who
    argv[#argv + 1] = "--dir"; argv[#argv + 1] = s.root
    local result = check.must(child.run(argv))
    assert(result.code == expected, result.stdout .. result.stderr)
    return result.stdout
  end
  cli({first}, 0)
  local before = check.must(refs.read_ref(s.root, "refs/heads/state"))
  local before_claim = check.must(boardread.list(s.root, before)).claims_by_id[first]
  assert(before_claim ~= nil)
  local output = cli({second, first}, 1)
  assert(output:find("batch rejected; no item succeeded", 1, true), output)
  assert(check.must(refs.read_ref(s.root, "refs/heads/state")) == before)
  local after = check.must(boardread.list(s.root, before))
  assert(after.claims_by_id[first].id == before_claim.id)
  assert(after.claims_by_id[second] == nil)
  assert(#check.must(staging.list(s.root)) == 0)
end
