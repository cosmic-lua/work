--- One validated ordinary commit as a complete native-board publication.
---
--- This module owns no transport and accepts no unvalidated commit.  A caller
--- either supplies the board validator that also derives the claim deadline,
--- or uses `collapse` as the temporary bridge from the format-6 transaction
--- staging model.  In both cases the resulting plan is one immutable,
--- single-parent local Git commit.
local git = require("_work.singlehead_git")
local literal = require("_work.singlehead_literal")
local objects = require("_work.stateplan_objects")
local projection = require("_work.stateplan_git")
local trailers = require("_work.stateplan_trailers")
local tx = require("_work.statetransaction")

local FORMAT < const > = "gitboard-snapshot-plan-v1"

local record Destination
  repository: string
  branch: string
  remote: string
  target_url: string
end

local record Author
  name: string
  email: string
  date: string
end

local record Identity
  parent: string
  tree: string
  message: string
  author: Author
end

local record Plan
  format: string
  destination: Destination
  local_commit: string
  parent: string
  base_tree: string
  tree: string
  message: string
  author: Author
  publish_by: integer
  entries: {{string: any}}
  complete_tree: boolean
end

--- The validator is the integration boundary for board rules and authority.
--- It returns the minimum deadline derived from the validated resulting board
--- and its claims; zero means the validated update has no lease deadline.
local type Validator = function(string, string, string): integer | nil, string
local type Gate = function(string, string, tx.Transition): boolean, string

local function destination_ok(value: Destination): boolean, string
  if objects.checked_repository(value.repository) ~= value.repository
  or objects.checked_branch(value.branch) ~= value.branch
  or value.remote == "" or value.remote:find("[%s%z]")
  or value.target_url == "" or value.target_url:find("[%z\r\n]") then
    return false, "invalid snapshot destination"
  end
  return true, ""
end

local function git_date_ok(value: string): boolean
  local epoch, hour, minute = value:match("^(%-?%d+) [+-](%d%d)(%d%d)$")
  return epoch ~= nil and math.tointeger(tonumber(epoch)) ~= nil
  and tonumber(hour) <= 23 and tonumber(minute) <= 59
end

local function author_ok(value: Author): boolean
  return value.name ~= "" and value.email ~= "" and value.date ~= ""
  and value.name:find("[\n\r<>]") == nil
  and value.email:find("[\n\r<>]") == nil
  and value.date:find("[\n\r]") == nil
  and git_date_ok(value.date)
end

--- Read the canonical logical author carried by an ordinary board commit.
--- Exactly one trailer is required; the obsolete Transaction identity is
--- refused because a snapshot commit is itself the publication identity.
local function logical_author(message: string): Author | nil, string
  local block, err = trailers.parse(message)
  if block == nil then return nil, err end
  local encoded: string | nil = nil
  local count = 0
  for line in block:gmatch("([^\n]+)") do
    local key, value = line:match("^([^:]+):%s*(.*)$")
    if key ~= nil and key:lower() == "transaction" then
      return nil, "snapshot message carries obsolete Transaction trailer"
    end
    if key ~= nil and key:lower() == "gitboard-author" then
      encoded, count = value, count + 1
    end
  end
  if count ~= 1 or encoded == nil then
    return nil, "snapshot message requires exactly one Gitboard-Author trailer"
  end
  local decoded, derr = literal.decode_object(encoded .. "\n")
  if decoded == nil then return nil, "invalid snapshot logical author: " .. derr end
  local author = decoded as Author -- cast: protected untrusted literal shape
  local ran, valid = pcall(author_ok, author)
  local canonical = literal.encode(decoded)
  if not ran or not valid or canonical == nil
  or canonical:gsub("\n$", "") ~= encoded then
    return nil, "invalid snapshot logical author"
  end
  return author, ""
end

--- Exact commit identity independent of provider-selected physical authorship.
local function commit_identity(root: string, sha: string): Identity | nil, string
  if not objects.checked_sha(sha, false) then
    return nil, "invalid snapshot commit ID"
  end
  local raw, err = git.run(root, {"cat-file", "commit", sha})
  if raw == nil then return nil, err end
  local header, message = raw:match("^(.-)\n\n(.*)$")
  if header == nil or message == nil then
    return nil, "malformed snapshot commit"
  end
  local tree = header:match("^tree ([0-9a-f]+)\n")
  local parents: {string} = {}
  for parent in header:gmatch("\nparent ([0-9a-f]+)") do
    parents[#parents + 1] = parent
  end
  if tree == nil or #parents ~= 1 then
    return nil, "snapshot commit must have exactly one parent"
  end
  local author, aerr = logical_author(message)
  if author == nil then return nil, aerr end
  return {parent = parents[1], tree = tree, message = message, author = author}, ""
end

local function same_author(a: Author, b: Author): boolean
  return a.name == b.name and a.email == b.email and a.date == b.date
end

local function validate(plan: Plan): boolean, string
  if plan.format ~= FORMAT then return false, "unsupported snapshot plan" end
  local ok, derr = destination_ok(plan.destination)
  if not ok then return false, derr end
  if not objects.checked_sha(plan.local_commit, false)
  or not objects.checked_sha(plan.parent, false)
  or not objects.checked_sha(plan.base_tree, false)
  or not objects.checked_sha(plan.tree, false)
  or plan.publish_by < 0 or not author_ok(plan.author) then
    return false, "invalid snapshot plan identity"
  end
  local author, aerr = logical_author(plan.message)
  if author == nil or not same_author(author, plan.author) then
    return false, aerr ~= "" and aerr or "snapshot logical author differs"
  end
  if not literal.is_sequence(plan.entries) then return false, "snapshot entries must be a sequence" end
  local prior = ""
  for _, entry in ipairs(plan.entries) do
    local path, mode, kind = entry.path, entry.mode, entry["type"]
    if not (path is string) or not tx.path_ok(path) or path <= prior
    or (mode ~= "100644" and mode ~= "100755" and mode ~= "120000")
    or kind ~= "blob" then return false, "invalid snapshot tree entry" end
    local content, sha = entry.content, entry.sha
    if (content is string) == (sha is string)
    or (sha is string and not objects.checked_sha(sha, false)) then
      return false, "snapshot tree entry needs exactly one content or SHA"
    end
    prior = path
  end
  return true, ""
end

--- Re-read the local object and prove every saved publication byte.
local function validate_local(root: string, plan: Plan): boolean, string
  local ok, err = validate(plan)
  if not ok then return false, err end
  local identity, ierr = commit_identity(root, plan.local_commit)
  if identity == nil then return false, ierr end
  if identity.parent ~= plan.parent then return false, "snapshot local commit has different parent" end
  if identity.tree ~= plan.tree then return false, "snapshot local commit has different tree" end
  local base_tree, berr = git.oid(root, plan.parent .. "^{tree}")
  if base_tree == nil then return false, berr end
  if base_tree ~= plan.base_tree then return false, "snapshot parent has different tree" end
  if identity.message ~= plan.message then return false, "snapshot local commit has different message" end
  if not same_author(identity.author, plan.author) then return false, "snapshot local commit has different logical author" end
  local physical, perr = git.run(root, {"cat-file", "commit", plan.local_commit})
  if physical == nil then return false, perr end
  local name, email, date = physical:match("\nauthor (.-) <([^>]+)> ([^\n]+)\n")
  if name ~= plan.author.name or email ~= plan.author.email or date ~= plan.author.date then
    return false, "snapshot local physical author differs from logical author"
  end
  local observed, oerr = projection.capture(root, plan.parent, plan.local_commit, {})
  if observed == nil then return false, oerr end
  local entries = literal.sequence() as {{string: any}} -- cast: connector sequence
  if plan.complete_tree then
    local captured, eerr = projection.snapshot(root, plan.local_commit, observed.changes)
    if captured == nil then return false, eerr end
    entries = captured
  else
    for _, change in ipairs(observed.changes) do
      if change.delete then return false, "delta snapshot cannot carry a deletion" end
      entries[#entries + 1] = {path = change.path, mode = change.mode,
        type = "blob", content = change.content}
    end
  end
  if literal.encode(entries) ~= literal.encode(plan.entries) then
    return false, "snapshot saved tree entries differ from local commit"
  end
  return true, ""
end

local function capture_validated(root: string, local_commit: string,
    destination: Destination, publish_by: integer): Plan | nil, string
  local identity, err = commit_identity(root, local_commit)
  if identity == nil then return nil, err end
  local observed, oerr = projection.capture(root, identity.parent, local_commit, {})
  if observed == nil then return nil, oerr end
  if #observed.changes == 0 then return nil, "snapshot has no meaningful final-state change" end
  local complete = false
  for _, change in ipairs(observed.changes) do if change.delete then complete = true end end
  local entries = literal.sequence() as {{string: any}} -- cast: connector sequence
  if complete then
    local captured, eerr = projection.snapshot(root, local_commit, observed.changes)
    if captured == nil then return nil, eerr end
    entries = captured
  else
    for _, change in ipairs(observed.changes) do
      entries[#entries + 1] = {path = change.path, mode = change.mode,
        type = "blob", content = change.content}
    end
  end
  local base_tree, berr = git.oid(root, identity.parent .. "^{tree}")
  if base_tree == nil then return nil, berr end
  local plan: Plan = {format = FORMAT, destination = destination,
    local_commit = local_commit, parent = identity.parent, base_tree = base_tree,
    tree = identity.tree, message = identity.message, author = identity.author,
    publish_by = publish_by,
    entries = entries, complete_tree = complete}
  local ok, verr = validate_local(root, plan)
  if not ok then return nil, verr end
  return plan, ""
end

--- Capture an existing ordinary commit only after board/authority validation.
local function capture(root: string, local_commit: string,
    destination: Destination, validator: Validator): Plan | nil, string
  local parent = git.text(root, {"show", "-s", "--format=%P", local_commit})
  if parent == nil or parent:match("^[0-9a-f]+$") == nil then
    return nil, "snapshot commit must have exactly one parent"
  end
  local publish_by, err = validator(root, parent, local_commit)
  if publish_by == nil then return nil, err ~= "" and err or "snapshot board validation failed" end
  if publish_by < 0 then return nil, "snapshot validator returned invalid deadline" end
  return capture_validated(root, local_commit, destination, publish_by)
end

local function summary_message(summary: string, author: Author): string | nil, string
  if summary == "" or summary:find("%z") then return nil, "snapshot summary is empty or invalid" end
  local parsed, err = trailers.parse(summary)
  if parsed == nil then return nil, err end
  for line in parsed:gmatch("([^\n]+)") do
    local key = line:match("^([^:]+):")
    if key ~= nil and (key:lower() == "transaction" or key:lower() == "gitboard-author") then
      return nil, "snapshot summary supplies a reserved publication trailer"
    end
  end
  local encoded = literal.encode(author)
  if encoded == nil then return nil, "cannot encode snapshot logical author" end
  return summary:gsub("\n*$", "") .. "\n\nGitboard-Author: "
  .. encoded:gsub("\n$", "") .. "\n", ""
end

--- Collapse a validated legacy transition chain to one final-state commit.
local function collapse(root: string, frozen: tx.Frozen, head: string,
    target_url: string, summary: string, gate?: Gate, now?: integer): Plan | nil, string
  local copy, err = tx.freeze(frozen)
  if copy == nil then return nil, err end
  if not objects.checked_sha(head, false) or copy.transitions[1].base ~= head then
    return nil, "snapshot chain does not start at canonical head"
  end
  local first_author = copy.transitions[1].author
  local author: Author = {name = first_author.name, email = first_author.email,
    date = first_author.date}
  local current, final_tree, deadline = head, "", 0
  for _, transition in ipairs(copy.transitions) do
    if transition.base ~= current then return nil, "snapshot transition chain is not contiguous" end
    if author.name ~= transition.author.name or author.email ~= transition.author.email then
      return nil, "snapshot transitions have different logical authors"
    end
    -- Separate commands naturally have separate author instants.  The final
    -- command's date becomes the immutable snapshot author's date.
    author.date = transition.author.date
    for _, dependency in ipairs(transition.dependencies) do
      local actual, derr = projection.path_id(root, current, dependency.path)
      if actual == nil then return nil, derr end
      if actual ~= dependency.id then return nil, "LOST_RACE: " .. dependency.path end
    end
    if transition.bounded then
      if gate == nil then return nil, "bounded transition requires gate validation" end
      local allowed, gerr = gate(root, current, transition)
      if not allowed then return nil, gerr end
    end
    if transition.publish_by > 0 and (deadline == 0 or transition.publish_by < deadline) then
      deadline = transition.publish_by
    end
    if deadline > 0 and (now or os.time()) >= deadline then return nil, "prepared claim expired" end
    final_tree, err = projection.apply(root, current, transition.changes)
    if final_tree == nil then return nil, err end
    current, err = projection.commit(root, current, final_tree, transition)
    if current == nil then return nil, err end
  end
  local message, merr = summary_message(summary, author)
  if message == nil then return nil, merr end
  local candidate, cerr = git.text(root, {"commit-tree", final_tree, "-p", head}, message, {
      GIT_AUTHOR_NAME = author.name, GIT_AUTHOR_EMAIL = author.email,
      GIT_AUTHOR_DATE = author.date, GIT_COMMITTER_NAME = "gitboard",
      GIT_COMMITTER_EMAIL = "gitboard@localhost", GIT_COMMITTER_DATE = author.date})
  if candidate == nil then return nil, cerr end
  local destination: Destination = {repository = copy.repository, branch = copy.branch,
    remote = copy.remote, target_url = target_url}
  return capture_validated(root, candidate, destination, deadline)
end

local record Module
  type Destination = Destination
  type Author = Author
  type Identity = Identity
  type Plan = Plan
  type Validator = Validator
  type Gate = Gate
  FORMAT: string
  validate: function(Plan): boolean, string
  validate_local: function(string, Plan): boolean, string
  commit_identity: function(string, string): Identity | nil, string
  message: function(string, Author): string | nil, string
  capture: function(string, string, Destination, Validator): Plan | nil, string
  capture_validated: function(string, string, Destination, integer): Plan | nil, string
  collapse: function(string, tx.Frozen, string, string, string, Gate | nil,
  integer | nil): Plan | nil, string
end

local M: Module = {FORMAT = FORMAT, validate = validate,
  validate_local = validate_local, commit_identity = commit_identity,
  message = summary_message, capture = capture,
  capture_validated = capture_validated, collapse = collapse}
return M
