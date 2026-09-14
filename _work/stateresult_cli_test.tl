#!/usr/bin/env cosmic
--- Research evidence names published state; an active draft cannot supply it.
local check = require("cosmic.check")
local child = require("cosmic.child")
local fixture = require("_work.fixture")
local fs = require("cosmic.fs")
local gitdraft = require("_work.gitdraft")
local item = require("_work.item")
local ksuid = require("_work.ksuid")
local proc = require("cosmic.proc")
local publish = require("_work.publish")
local refs = require("_work.refs")
local staging = require("_work.statestaging")
local stateinit = require("_work.stateinit")
local store = require("_work.store")
local write = require("_work.storewrite")

local function test_cli_result_requires_a_published_snapshot()
  local root = fs.join(fixture.tmpdir, "native-result-draft")
  assert(fs.remove_all(root) and fs.make_dirs(root))
  assert(stateinit.init(root) and refs.set_board_mode(root, "local"))
  local s = check.must(store.open(root))
  local board = check.must(store.list(s))[1]
  local research = check.must(item.decode({id = ksuid.new(), title = "Measured research", parent = board.id}))
  research.builders = {"0123456789abcdef0123456789abcdef"}
  assert(write.save(s, research, "new research", {
        change = "Record the observed behavior and recommendation.", non_goals = "No product changes."}))
  assert(publish.publish(s))
  assert(store.close(s))
  local runtime = check.must(proc.interpreter())
  local function cli(args: {string}, expected: integer): string
    local argv = {runtime, "cmd/gitboard/main.tl"}
    for _, word in ipairs(args) do argv[#argv + 1] = word end
    for _, word in ipairs({"--dir", root, "--session", "0123456789abcdef0123456789abcdef"}) do
      argv[#argv + 1] = word
    end
    local result = check.must(child.run(argv, {cwd = "."}))
    assert(result.code == expected, result.stdout .. result.stderr)
    return result.stdout
  end
  cli({"claim", research.id}, 0)
  local head = check.must(refs.read_ref(root, "refs/heads/state"))
  local draft = check.must(gitdraft.begin(root))
  local before = check.must(staging.load(root, draft.staging_ref))
  local refusal = cli({"take", research.id, "--result", "--draft", draft.id}, 1)
  assert(refusal:find("publish the draft before recording research evidence", 1, true), refusal)
  assert(check.must(refs.read_ref(root, "refs/heads/state")) == head)
  assert(check.must(staging.load(root, draft.staging_ref)).sha == before.sha,
    "refused result must not append to the draft")
  -- The same claimed item and spec work when no draft is selected. This
  -- control prevents another refusal from masking a missing draft guard.
  cli({"take", research.id, "--result"}, 0)
  local confirmed = check.must(store.open(root))
  local result = check.must(store.load(confirmed, research.id))
  assert(result.result == head, "research evidence must name the observed published state")
  assert(store.close(confirmed))
end
