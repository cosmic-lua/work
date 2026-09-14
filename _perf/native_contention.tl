#!/usr/bin/env cosmic
--- Measure native single-ref contention with the production CLI. Every writer
--- stages a disjoint item edit from one head, then all `publish --execute`
--- processes start before any is awaited. Git trace2 counts actual push attempts;
--- the cosmic.literal report is data that can be checked into an experiment.
local check = require("cosmic.check")
local child = require("cosmic.child")
local env = require("cosmic.env")
local fs = require("cosmic.fs")
local item = require("_work.item")
local ksuid = require("_work.ksuid")
local literal = require("_work.singlehead_literal")
local publish = require("_work.publish")
local refs = require("_work.refs")
local stateinit = require("_work.stateinit")
local store = require("_work.store")
local write = require("_work.storewrite")

local GITBOARD < const > = os.getenv("GITBOARD_PERF_BIN") or "o/bin/gitboard"

local record Writer
  root: string
  trace: string
  handle: child.Handle
end

local function git(root: string, arguments: {string}): string
  local argv = {"git", "-c", "user.name=contention",
    "-c", "user.email=contention@board"}
  for _, argument in ipairs(arguments) do argv[#argv + 1] = argument end
  local result = check.must(child.run(argv, {cwd = root}))
  assert(result.ok, result.stderr)
  local cleaned = result.stdout:gsub("%s+$", "")
  return cleaned
end

local function cli(root: string, arguments: {string}): child.Result
  local argv = {GITBOARD}
  for _, argument in ipairs(arguments) do argv[#argv + 1] = argument end
  argv[#argv + 1] = "--dir"
  argv[#argv + 1] = root
  return check.must(child.run(argv))
end

local function push_count(path: string): integer
  local raw = check.must(fs.read(path))
  local count, offset = 0, 1
  while true do
    local found = raw:find('"argv":["git","push"', offset, true)
    if found == nil then return count end
    count, offset = count + 1, found + 1
  end
end

local function one(width: integer): {string: any}
  assert(width >= 2 and width <= 32)
  local base = fs.join(os.getenv("TEST_TMPDIR") or "/tmp",
    "native-contention-" .. tostring(width))
  assert(fs.remove_all(base) and fs.make_dirs(base))
  local seed = fs.join(base, "seed")
  assert(fs.make_dirs(seed) and stateinit.init(seed))
  assert(refs.set_board_mode(seed, "local"))
  local seeded = check.must(store.open(seed))
  local board = check.must(store.list(seeded))[1]
  local ids: {string} = {}
  for index = 1, width do
    local candidate = check.must(item.decode({id = ksuid.new(),
          title = "contention item " .. tostring(index), parent = board.id}))
    assert(write.save(seeded, candidate, "seed disjoint item"))
    assert(publish.publish(seeded))
    ids[#ids + 1] = candidate.id
  end
  git(seed, {"symbolic-ref", "HEAD", "refs/heads/state"})
  local remote = fs.join(base, "remote.git")
  git(base, {"clone", "-q", "--bare", seed, remote})
  local initial = git(remote, {"rev-parse", "refs/heads/state"})
  local roots: {string} = {}
  for index = 1, width do
    local root = fs.join(base, "writer-" .. tostring(index))
    git(base, {"clone", "-q", remote, root})
    assert(refs.set_board_mode(root, "remote"))
    git(root, {"config", "gitboard.publicationRepository", "proof/board"})
    local staged = cli(root, {"set", ids[index], "--title",
        "writer " .. tostring(index) .. " landed"})
    assert(staged.code == 0, staged.stdout .. staged.stderr)
    roots[#roots + 1] = root
  end
  local writers: {Writer} = {}
  for index, root in ipairs(roots) do
    local trace = fs.join(base, "writer-" .. tostring(index) .. ".trace")
    local variables = env.list({set = {GIT_TRACE2_EVENT = trace}})
    local handle = check.must(child.start({GITBOARD, "publish", "--execute",
          "--dir", root}, {env = variables}))
    writers[#writers + 1] = {root = root, trace = trace, handle = handle}
  end
  local attempts = literal.sequence()
  local successes, failures, maximum = 0, 0, 0
  for _, writer in ipairs(writers) do
    local result = check.must(writer.handle:wait(120000))
    local count = push_count(writer.trace)
    attempts[#attempts + 1] = count
    maximum = math.max(maximum, count)
    if result.code == 2 then successes = successes + 1
    else
      assert(result.code == 1, result.stdout .. result.stderr)
      failures = failures + 1
    end
  end
  local final = git(remote, {"rev-parse", "refs/heads/state"})
  local landed = math.tointeger(tonumber(git(remote,
        {"rev-list", "--count", initial .. ".." .. final}))) or -1
  assert(landed == successes, "each successful disjoint writer lands one commit")
  return {writers = width, successes = successes, failures = failures,
    max_push_attempts = maximum, push_attempts = attempts,
    policy_max_attempts = 5, backoff = "none"}
end

local requested: {integer} = {}
for _, raw in ipairs({...}) do
  local width = math.tointeger(tonumber(raw))
  assert(width ~= nil, "writer counts must be integers")
  requested[#requested + 1] = width
end
if #requested == 0 then requested = {2, 4, 8} end
local measurements = literal.sequence()
for _, width in ipairs(requested) do measurements[#measurements + 1] = one(width) end
print(check.must(literal.encode({format = "gitboard-native-contention-v1",
        measurements = measurements})))
