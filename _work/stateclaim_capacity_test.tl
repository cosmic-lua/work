#!/usr/bin/env cosmic
--- Direct CLI claim sets provide exclusion without applying the pull capacity gate.
local boardread = require("_work.boardread")
local boardtree = require("_work.boardtree")
local check = require("cosmic.check")
local child = require("cosmic.child")
local fixture = require("_work.fixture")
local fs = require("cosmic.fs")
local proc = require("cosmic.proc")
local gitobj = require("_work.gitobj")
local item = require("_work.item")
local ksuid = require("_work.ksuid")
local refs = require("_work.refs")
local stateinit = require("_work.stateinit")
local flow = require("_work.flow")
local function test_cli_claim_set_may_exceed_pull_capacity_and_keeps_exclusion()
  local root = fs.join(fixture.tmpdir, "native-cli-claim-capacity")
  assert(fs.remove_all(root)); assert(fs.make_dirs(root)); assert(stateinit.init(root))
  assert(refs.set_board_mode(root, "local"))
  local initial = check.must(refs.read_ref(root, "refs/heads/state"))
  local board = check.must(boardread.list(root, initial)).items[1]
  local outcome = check.must(item.decode({id = ksuid.new(), title = "outcome", parent = board.id}))
  local all: {item.Item} = {board, outcome}
  local leaves: {string} = {}
  for index = 1, flow.DOING_LIMIT + 1 do
    local leaf = check.must(item.decode({id = ksuid.new(), title = "work " .. index, parent = outcome.id}))
    all[#all + 1] = leaf; leaves[#leaves + 1] = leaf.id
  end
  local entries: {gitobj.TreeEntry} = {}
  for _, it in ipairs(all) do
    entries[#entries + 1] = {mode = "40000", otype = "tree", name = it.id,
      sha = check.must(boardtree.build_item(root, it, nil, nil, true))}
  end
  local tree = check.must(gitobj.mktree_write(root, {
        {mode = "100644", otype = "blob", name = "format", sha = check.must(gitobj.hash_object_write(root, "6\n"))},
        {mode = "40000", otype = "tree", name = "items", sha = check.must(gitobj.mktree_write(root, entries))}}))
  local head = check.must(gitobj.commit_tree(root, {tree = tree, parents = {initial}, message = "capacity fixture",
        author_name = "test", author_email = "test@board", committer_name = "test", committer_email = "test@board"}))
  assert(refs.update_ref(root, "refs/heads/state", head, initial))
  local function cli(args: {string}, expected: integer): string
    local argv: {string} = {check.must(proc.interpreter()), "cmd/gitboard/main.tl"}
    for _, word in ipairs(args) do argv[#argv + 1] = word end
    for _, word in ipairs({"--dir", root, "--session", "0123456789abcdef0123456789abcdef"}) do argv[#argv + 1] = word end
    local ran = check.must(child.run(argv, {cwd = "."}))
    assert(ran.code == expected, ran.stdout .. ran.stderr)
    return ran.stdout
  end
  local acquire: {string} = {"claim"}
  for _, id in ipairs(leaves) do acquire[#acquire + 1] = id end
  cli(acquire, 0)
  local acquired_head = check.must(refs.read_ref(root, "refs/heads/state"))
  local acquired = check.must(boardread.list(root, acquired_head))
  local count = 0
  for _ in pairs(acquired.claims_by_id) do count = count + 1 end
  assert(count == #leaves and count > flow.DOING_LIMIT,
    "the complete direct claim set may exceed pull capacity")
  local first_identity = acquired.claims_by_id[leaves[1]].id
  local overlap = cli({"claim", leaves[1], leaves[#leaves]}, 1)
  assert(overlap:find("batch rejected; no item succeeded", 1, true), overlap)
  assert(check.must(refs.read_ref(root, "refs/heads/state")) == acquired_head,
    "overlapping acquisition leaves the entire set unchanged")
  cli({"renew", leaves[1]}, 0)
  local renewed = check.must(boardread.list(root, check.must(refs.read_ref(root, "refs/heads/state"))))
  assert(renewed.claims_by_id[leaves[1]].id == first_identity)
  cli({"drop", leaves[1], "--why", "release exclusion"}, 0)
  local dropped = check.must(boardread.list(root, check.must(refs.read_ref(root, "refs/heads/state"))))
  assert(dropped.claims_by_id[leaves[1]] == nil)
  assert(dropped.claims_by_id[leaves[#leaves]].id == acquired.claims_by_id[leaves[#leaves]].id)
  cli({"claim", leaves[1]}, 0)
  local final = check.must(boardread.list(root, check.must(refs.read_ref(root, "refs/heads/state"))))
  assert(final.claims_by_id[leaves[1]].id ~= first_identity,
    "a new acquisition after release has a new identity")
  assert(final.claims_by_id[leaves[#leaves]].id == acquired.claims_by_id[leaves[#leaves]].id)
end
