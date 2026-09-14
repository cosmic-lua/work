#!/usr/bin/env cosmic
--- Production CLI proof of the snapshot connector protocol. A local bare Git
--- repository emulates the provider Git Database API, including a different
--- physical commit author and a lost successful update acknowledgement.
local check = require("cosmic.check")
local child = require("cosmic.child")
local fixture = require("_work.fixture")
local fs = require("cosmic.fs")
local json = require("cosmic.json")
local refs = require("_work.refs")
local stateinit = require("_work.stateinit")
local store = require("_work.store")
local workspace = require("_work.snapshot_workspace")
local git = require("_work.singlehead_git")

local record Result code: integer stdout: string stderr: string end

local function cli(root: string, args: {string}): Result
  local argv: {string} = {"o/bin/gitboard"}
  for _, word in ipairs(args) do argv[#argv + 1] = word end
  argv[#argv + 1] = "--dir"; argv[#argv + 1] = root
  local result = check.must(child.run(argv, {cwd = "."}))
  assert(result.code == 0, result.stdout .. result.stderr)
  return {code = result.code, stdout = result.stdout, stderr = result.stderr}
end

local function object(root: string, args: {string}): {string: any}
  return check.must(json.decode_object(cli(root, args).stdout))
end

local function resolve(value: any, outputs: {string: string}): any
  if not (value is string) then return value end
  local id = value:match("^%$(.+)%.sha$")
  return id ~= nil and assert(outputs[id], "missing provider result " .. id)
  or value
end

local function provider_tree(remote: string, arguments: {string: any},
    outputs: {string: string}): string
  local dir = check.must(fs.temp_dir(fs.join(fixture.tmpdir,
        "snapshot-provider-index-XXXXXX")))
  local environment = {GIT_INDEX_FILE = fs.join(dir, "index")}
  local base = arguments.base_tree_sha
  local read = {"read-tree", "--empty"}
  if base is string and base ~= "" then
    local sha = resolve(base, outputs); assert(sha is string)
    read = {"read-tree", sha}
  end
  local _, rerr = git.run(remote, read, nil, environment)
  assert(rerr == "", rerr)
  local elements = arguments.tree_elements
  assert(elements is {any})
  for _, raw in ipairs(elements) do
    assert(raw is {string: any}); local element = raw
    local sha = resolve(element.sha, outputs)
    if not (sha is string) then
      local content = element.content
      assert(content is string)
      sha = check.must(git.text(remote, {"hash-object", "-w", "--stdin"},
          content))
    end
    assert(sha is string)
    local mode, path = element.mode, element.path
    assert(mode is string and path is string)
    local _, uerr = git.run(remote, {"update-index", "--add", "--cacheinfo",
        mode, sha, path}, nil, environment)
    assert(uerr == "", uerr)
  end
  local tree = check.must(git.text(remote, {"write-tree"}, nil, environment))
  assert(fs.remove_all(dir))
  return tree
end

local function provider_commit(remote: string, arguments: {string: any}): string
  local parent, tree, message = arguments.parent_sha, arguments.tree_sha,
  arguments.message
  assert(parent is string and tree is string and message is string)
  return check.must(git.text(remote, {"commit-tree", tree,
        "-p", parent}, message, {
        GIT_AUTHOR_NAME = "Connector Fixture",
        GIT_AUTHOR_EMAIL = "connector@provider.test",
        GIT_AUTHOR_DATE = "1700000000 +0000",
        GIT_COMMITTER_NAME = "Connector Fixture",
        GIT_COMMITTER_EMAIL = "connector@provider.test",
        GIT_COMMITTER_DATE = "1700000000 +0000",
      }))
end

local function setup(): string, string
  local base = fs.join(fixture.tmpdir, "snapshot-connector-cycle")
  assert(fs.remove_all(base) and fs.make_dirs(base))
  local seed = fs.join(base, "seed")
  assert(fs.make_dirs(seed) and stateinit.init(seed))
  assert(refs.set_board_mode(seed, "local"))
  fixture.git(seed, {"symbolic-ref", "HEAD", "refs/heads/state"})
  local remote, root = fs.join(base, "remote.git"), fs.join(base, "client")
  fixture.git(base, {"clone", "-q", "--bare", seed, remote})
  fixture.git(base, {"clone", "-q", remote, root})
  assert(refs.set_board_mode(root, "remote"))
  assert(refs.ensure_refspecs(root) and refs.fetch_prune(root))
  fixture.git(root, {"config", "gitboard.publicationRepository", "proof/board"})
  return root, remote
end

local function test_production_cli_snapshot_connector_cycle()
  local root, remote = setup()
  local spec = fs.join(root, "research.md")
  assert(fs.write(spec, [[## Change

Exercise the current snapshot connector protocol.

## Non-goals

No product repository change.
]]))
  cli(root, {"new", "connector snapshot", "--spec-file", spec})
  local local_commit = check.must(workspace.read(root)).commit
  local begin = object(root, {"publish", local_commit, "--protocol", "begin"})
  local parent, final_tree = begin.parent, begin.tree
  assert(begin.commit == local_commit and parent is string
    and final_tree is string and begin.repository == "proof/board")

  local listed = object(root, {"publish", local_commit, "--protocol", "trees"})
  local raw_calls = listed.calls; assert(raw_calls is {any} and #raw_calls == 1)
  local outputs: {string: string} = {}
  local last_tree = ""
  for _, raw in ipairs(raw_calls) do
    assert(raw is {string: any}); local call = raw
    local id, arguments = call.id, call.arguments
    assert(id is string and call.tool == "github_create_tree"
      and arguments is {string: any})
    last_tree = provider_tree(remote, arguments, outputs)
    outputs[id] = last_tree
  end
  assert(last_tree == final_tree, "provider reconstructed the exact final tree")

  local commit_call = object(root, {"publish", local_commit, "--protocol",
      "commit", "--returned-tree", last_tree})
  local commit_arguments = commit_call.arguments
  assert(commit_call.tool == "github_create_commit"
    and commit_arguments is {string: any})
  local published = provider_commit(remote, commit_arguments)
  assert(published ~= local_commit, "provider physical author changes the SHA")
  local candidate = object(root, {"publish", local_commit, "--protocol",
      "candidate", "--candidate", published})
  assert(candidate.status == "candidate" and candidate.candidate == published)

  local observed = check.must(refs.read_ref(remote, "refs/heads/state"))
  local update = object(root, {"publish", local_commit, "--protocol", "update",
      "--head", observed})
  local arguments = update.arguments
  assert(update.tool == "github_update_ref" and arguments is {string: any})
  assert(arguments.sha == published and arguments.force == false)
  assert(refs.update_ref(remote, "refs/heads/state", published, observed))
  -- The provider update succeeded but its response was lost. A fresh process
  -- fetches and reconciles from the durable candidate without another write.
  fixture.git(root, {"fetch", "-q", "origin",
      "+refs/heads/state:refs/remotes/origin/state"})
  local reconciled = object(root, {"publish", local_commit, "--protocol",
      "reconcile", "--head", published})
  assert(reconciled.status == "confirmed" and reconciled.candidate == published)
  assert(workspace.read(root) == nil)

  local local_tree = check.must(git.text(root, {"rev-parse", local_commit .. "^{tree}"}))
  local remote_tree = check.must(git.text(remote, {"rev-parse", published .. "^{tree}"}))
  assert(local_tree == remote_tree)
  local logical = check.must(git.text(remote,
      {"show", "-s", "--format=%B", published}))
  assert(logical:find("Gitboard%-Author:") ~= nil)
  assert(check.must(git.text(remote, {"show", "-s", "--format=%an <%ae>",
          published})) == "Connector Fixture <connector@provider.test>")
  local current = check.must(store.open(root))
  local found = false
  for _, it in ipairs(check.must(store.list(current))) do
    if it.title == "connector snapshot" then found = true end
  end
  assert(found, "confirmed provider state is readable through the production store")
end
