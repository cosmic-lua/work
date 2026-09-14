--- Faithful local executor for the production native connector call stream.
--- It models GitHub's Git Database API against a bare repository: blobs and
--- trees are written independently, commits get the provider's physical
--- identity, and the one non-forced ref update is the publication point.
local check = require("cosmic.check")
local child = require("cosmic.child")
local fs = require("cosmic.fs")
local json = require("cosmic.json")
local git = require("_work.singlehead_git")
local plans = require("_work.stateplan")
local refs = require("_work.refs")
local staging = require("_work.statestaging")

local record Result
  code: integer
  stdout: string
  stderr: string
end

local record Execution
  published: string
  candidate: string
  plan_path: string
  calls: integer
  trees: integer
  commits: integer
  uncertain: boolean
end

local final_guard_probed = false

local function cli(root: string, args: {string}, expected?: integer): Result
  local runtime = os.getenv("GITBOARD_NATIVE_CONNECTOR_RUNTIME")
  local argv: {string} = runtime ~= nil
  and {runtime, "cmd/gitboard/main.tl"} or {"o/bin/gitboard"}
  for _, argument in ipairs(args) do argv[#argv + 1] = argument end
  argv[#argv + 1] = "--dir"
  argv[#argv + 1] = root
  local result = check.must(child.run(argv, {cwd = "."}))
  assert(result.code == (expected or 0), result.stdout .. result.stderr)
  return {code = result.code, stdout = result.stdout, stderr = result.stderr}
end

local function resolved(value: any, outputs: {string: string}): any
  if not (value is string) then return value end
  local id = value:match("^%$(.+)%.sha$")
  if id == nil then return value end
  local output = outputs[id]
  assert(output ~= nil, "connector call references no prior result: " .. id)
  return output
end

local function write_tree(remote: string, arguments: {string: any},
    outputs: {string: string}): string
  local temporary = check.must(fs.temp_dir(fs.join(
        os.getenv("TEST_TMPDIR") or "/tmp", "connector-index-XXXXXX")))
  local environment = {GIT_INDEX_FILE = fs.join(temporary, "index")}
  local base = arguments.base_tree_sha
  local read_args: {string} = {"read-tree", "--empty"}
  if base is string then
    local base_sha = resolved(base, outputs)
    assert(base_sha is string)
    read_args = {"read-tree", base_sha}
  end
  local _, read_err = git.run(remote, read_args, nil, environment)
  assert(read_err == "", read_err)
  local elements = arguments.tree_elements
  assert(elements is {any}, "tree_elements must be a connector array")
  for _, raw_element in ipairs(elements) do
    assert(raw_element is {string: any})
    local element = raw_element
    assert(element["type"] == "blob", "the native board stores blob leaves")
    local sha = element.sha
    if sha is string then sha = resolved(sha, outputs)
    else
      local content = element.content
      assert(content is string, "a tree leaf needs content or sha")
      sha = check.must(git.text(remote, {"hash-object", "-w", "--stdin"},
          content))
    end
    local mode, path = element.mode, element.path
    assert(mode is string and sha is string and path is string)
    local _, update_err = git.run(remote, {"update-index", "--add", "--cacheinfo",
        mode, sha, path}, nil,
      environment)
    assert(update_err == "", update_err)
  end
  local tree = check.must(git.text(remote, {"write-tree"}, nil, environment))
  assert(fs.remove_all(temporary))
  return tree
end

local function write_commit(remote: string, arguments: {string: any},
    outputs: {string: string}): string
  local parent = resolved(arguments.parent_sha, outputs)
  local tree = resolved(arguments.tree_sha, outputs)
  local message = arguments.message
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

local function record_returned(root: string, plan_path: string,
    plan: plans.Plan, published: string)
  cli(root, {"publish", "--from-plan", plan_path, "--published",
      published, "--repository", plan.frozen.repository}, nil)
  local recorded = false
  for _, receipt in ipairs(check.must(staging.list(root, "prepared"))) do
    if receipt.transaction == plan.frozen.transaction
    and receipt.tip == plan.frozen.staging_sha then
      assert(receipt.published == published,
        "the provider-returned commit must be recorded exactly")
      recorded = true
    end
  end
  assert(recorded, "published attempt receipt is missing before github_update_ref")
end

--- Execute every call by asking the production CLI to render that exact index.
--- `uncertain_update` lands the final CAS but reports an unknown outcome to the
--- caller, reproducing a provider response lost after publication.
local function execute(root: string, remote: string, plan_path: string,
    uncertain_update?: boolean): Execution
  local plan = check.must(plans.load(plan_path))
  local outputs: {string: string} = {}
  local last_commit, trees, commits = "", 0, 0
  for index = 1, #plan.calls do
    local args = {"publish", "--from-plan", plan_path, "--call",
      tostring(index - 1), "--call-json", "--repository",
      plan.frozen.repository}
    if index == #plan.calls then
      if not final_guard_probed then
        cli(root, args, 1)
        local wrong: {string} = {}
        for _, argument in ipairs(args) do wrong[#wrong + 1] = argument end
        wrong[#wrong + 1] = "--head"
        wrong[#wrong + 1] = refs.ZERO_SHA
        cli(root, wrong, 1)
        final_guard_probed = true
      end
      local observed = check.must(refs.read_ref(remote, "refs/heads/state"))
      args[#args + 1] = "--head"
      args[#args + 1] = observed
    end
    local rendered = cli(root, args, nil).stdout
    local call = check.must(json.decode_object(rendered))
    local id, tool, raw_arguments = plan.calls[index].id,
    call.tool, call.arguments
    assert(tool is string and raw_arguments is {string: any})
    local arguments = raw_arguments
    if tool == "github_create_tree" then
      assert(arguments.repository_full_name == plan.frozen.repository
        and arguments.repo == nil)
      outputs[id] = write_tree(remote, arguments, outputs)
      trees = trees + 1
    elseif tool == "github_create_commit" then
      assert(arguments.repository_full_name == plan.frozen.repository
        and arguments.repo == nil)
      last_commit = write_commit(remote, arguments, outputs)
      outputs[id] = last_commit
      commits = commits + 1
      if index == #plan.calls - 1 then
        record_returned(root, plan_path, plan, last_commit)
      end
    else
      assert(tool == "github_update_ref" and index == #plan.calls,
        "only the final connector call may publish")
      assert(arguments.repository_full_name == plan.frozen.repository
        and arguments.repo == nil)
      assert(arguments.branch_name == "state" and arguments.force == false)
      assert(check.must(refs.read_ref(remote, "refs/heads/state"))
        == plan.expected_head, "final-call exact-head guard failed")
      local next_sha = resolved(arguments.sha, outputs)
      assert(next_sha is string and next_sha == last_commit)
      assert(refs.update_ref(remote, "refs/heads/state", next_sha,
          plan.expected_head))
    end
  end
  assert(commits == #plan.frozen.transitions and last_commit ~= "")
  return {published = last_commit, candidate = plan.candidate,
    plan_path = plan_path, calls = #plan.calls, trees = trees,
    commits = commits, uncertain = uncertain_update or false}
end

--- Freeze one outstanding receipt through the CLI, execute its indexed call
--- stream, record the provider-returned commit (which exists before
--- github_update_ref),
--- and let production refresh verify fetched content before retiring it.
local function publish(root: string, remote: string, label: string,
    uncertain_update?: boolean): Execution
  local outstanding = check.must(staging.list(root))
  assert(#outstanding == 1, "connector proof expects one outstanding attempt")
  local plan_path = fs.join(root, label .. ".literal")
  cli(root, {"publish", outstanding[1].id, "--plan", plan_path})
  local result = execute(root, remote, plan_path, uncertain_update)
  local plan = check.must(plans.load(plan_path))
  local function chain(repository: string, tip: string): {string}
    local raw = check.must(git.run(repository, {"rev-list", "--first-parent",
          "--reverse", plan.expected_head .. ".." .. tip}))
    local out: {string} = {}
    for sha in raw:gmatch("([0-9a-f]+)") do out[#out + 1] = sha end
    return out
  end
  local shell, connector = chain(root, result.candidate),
  chain(remote, result.published)
  assert(#shell == #plan.frozen.transitions and #connector == #shell)
  for index = 1, #shell do
    local shell_tree = check.must(git.text(root,
        {"rev-parse", shell[index] .. "^{tree}"}))
    local connector_tree = check.must(git.text(remote,
        {"rev-parse", connector[index] .. "^{tree}"}))
    assert(shell_tree == connector_tree,
      "shell and connector transition trees differ")
    local shell_message = check.must(git.run(root,
        {"show", "-s", "--format=%B", shell[index]}))
    local connector_message = check.must(git.run(remote,
        {"show", "-s", "--format=%B", connector[index]}))
    assert(shell_message == connector_message,
      "shell and connector transition messages differ")
  end
  assert(result.candidate ~= result.published,
    "different physical authors must mint different commit ids")
  local physical = check.must(git.text(remote,
      {"show", "-s", "--format=%an <%ae>", result.published}))
  assert(physical == "Connector Fixture <connector@provider.test>")
  cli(root, {"refresh", "--execute"})
  assert(#check.must(staging.list(root)) == 0)
  return result
end

local record Module
  type Execution = Execution
  cli: function(string, {string}, integer | nil): Result
  execute: function(string, string, string, boolean | nil): Execution
  publish: function(string, string, string, boolean | nil): Execution
end

local M: Module = {cli = cli, execute = execute, publish = publish}
return M
