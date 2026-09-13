local check = require("cosmic.check")
local fs = require("cosmic.fs")
local child = require("cosmic.child")
local fixture = require("_work.fixture")
local init = require("_work.stateinit")
local refs = require("_work.refs")
local store = require("_work.store")
local native = require("_work.stateclaim_authority")
local claim = require("_work.claim")
local receipt = require("_work.preparation_receipt")
local staging = require("_work.statestaging")
local boardread = require("_work.boardread")
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
  local who = "0123456789abcdef0123456789abcdef"
  cli({"claim", id, "--session", who}, 2)
  local pending = check.must(staging.list(root)); assert(#pending == 1)
  assert(native.current(check.must(store.open(root)), id, who) == nil)
  cli({"publish", pending[1].id, "--execute"}, 2)
  cli({"refresh", "--execute"})

  cli({"renew", id, "--session", who, "--execute"})
  cli({"drop", id, "--session", who, "--why", "done", "--execute"})
  local head = check.must(refs.read_ref(root, "refs/remotes/origin/state")); assert(check.must(boardread.list(root, head)).claims_by_id[id] == nil)

end
