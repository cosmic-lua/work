--- Frozen, complete legacy namespace snapshots and exact commit records.
local child = require("cosmic.child")
local env = require("cosmic.env")
local gitobj = require("_work.gitobj")

local record Event
  sha: string
  ref: string
  id: string
  parent: string
  tree: string
  author: string
  committer: string
  seconds: integer
  message: string
end

local function git(root: string, args: {string}, input?: string): string | nil, string
  local argv: {string} = {"git", "-c", "core.createObject=rename"}
  for _, value in ipairs(args) do argv[#argv + 1] = value end
  local r, err = child.run(argv, {cwd = root, stdin = input,
      env = env.list({set = {GIT_NO_LAZY_FETCH = "1", GIT_NO_REPLACE_OBJECTS = "1"}})})
  if r == nil then return nil, err end
  if not r.ok then return nil, r.stderr end
  return r.stdout, ""
end

local function source_name(ref: string, prefix: string): boolean
  local name = ref:sub(#prefix + 1)
  return ref:sub(1, #prefix) == prefix and
  (name:match("^items/") ~= nil or name:match("^ended/") ~= nil
    or name:match("^claim%-batches/") ~= nil or name == "board/seq")
end

local function snapshot(root: string, prefix: string): {string: string} | nil, string
  if prefix:sub(1, 5) ~= "refs/" or prefix:sub(-1) ~= "/"
  or prefix:find("[%s%c]") then return nil, "invalid source ref prefix" end
  local raw, err = git(root, {"for-each-ref", "--format=%(refname) %(objectname)", prefix})
  if raw == nil then return nil, err end
  local out: {string: string} = {}
  for name, sha in raw:gmatch("([^%s]+) ([0-9a-f]+)\n") do
    if source_name(name, prefix) then out[name] = sha end
  end
  return out, ""
end

local function compare(expected: {string: string}, actual: {string: string}): boolean, string
  local changes: {string} = {}
  for ref, sha in pairs(expected) do
    if actual[ref] == nil then changes[#changes + 1] = "removed " .. ref
    elseif actual[ref] ~= sha then changes[#changes + 1] = "moved " .. ref end
  end
  for ref in pairs(actual) do
    if expected[ref] == nil then changes[#changes + 1] = "added " .. ref end
  end
  table.sort(changes)
  if #changes > 0 then return false, "source drift: " .. table.concat(changes, "; ") end
  return true, ""
end

local function integrity(root: string, refs: {string: string}): boolean, string
  local shallow, err = git(root, {"rev-parse", "--is-shallow-repository"})
  if shallow == nil then return false, err end
  if shallow:match("true") then return false, "migration refuses a shallow source" end
  local config, cerr = git(root, {"config", "--list"})
  if config == nil then return false, cerr end
  for line in config:gmatch("[^\n]+") do
    if line:lower():match("^remote%..*%.promisor=")
    or line:lower():match("^extensions%.partialclone=") then
      return false, "migration refuses a promisor/partial source"
    end
  end
  local tips: {string} = {}
  for _, sha in pairs(refs) do tips[#tips + 1] = sha end
  if #tips == 0 then return false, "no legacy source refs" end
  table.sort(tips)
  local closure, e = git(root, {"rev-list", "--objects", "--missing=print", "--stdin"},
    table.concat(tips, "\n") .. "\n")
  if closure == nil then return false, "missing source closure: " .. e end
  if closure:match("^%?") or closure:match("\n%?") then
    return false, "missing source closure: " .. closure
  end
  return true, ""
end

local function parse(sha: string, ref: string, id: string, raw: string): Event | nil, string
  local header, message = raw:match("^(.-)\n\n(.*)$")
  if header == nil then return nil, "malformed source commit " .. sha end
  local author = header:match("\nauthor ([^\n]+)")
  local committer = header:match("\ncommitter ([^\n]+)")
  local tree = header:match("^tree ([0-9a-f]+)")
  if author == nil or committer == nil or tree == nil then
    return nil, "incomplete source identity " .. sha
  end
  local seconds = math.tointeger(tonumber(committer:match(" (%-?%d+) [%+%-]%d%d%d%d$")))
  if seconds == nil then return nil, "invalid source date " .. sha end
  return {sha = sha, ref = ref, id = id, parent = header:match("\nparent ([0-9a-f]+)") or "",
    tree = tree, author = author, committer = committer, seconds = seconds, message = message}, ""
end

--- Kahn's algorithm uses dates ONLY among ready nodes, never violating
--- parent order when a clock moved backwards. Shared ancestors replay once.
local function events(root: string, refs: {string: string}, prefix: string): {Event} | nil, string
  local names: {string} = {}
  for ref in pairs(refs) do names[#names + 1] = ref end
  table.sort(names)
  local by_sha: {string: Event} = {}
  for _, ref in ipairs(names) do
    local short = ref:sub(#prefix + 1)
    local id = short:match("^items/(.+)$") or short:match("^ended/(.+)$")
    if id ~= nil then
      if not id:match("^[%w_-]+$") then return nil, "unsafe item id " .. id end
      local raw, err = git(root, {"rev-list", "--first-parent", "--reverse", refs[ref]})
      if raw == nil then return nil, err end
      local shas: {string} = {}
      for sha in raw:gmatch("[0-9a-f]+") do shas[#shas + 1] = sha end
      local objects, oerr = gitobj.cat_file_batch(root, shas)
      if objects == nil then return nil, oerr end
      for _, sha in ipairs(shas) do
        if by_sha[sha] ~= nil then
          if by_sha[sha].id ~= id then return nil, "shared source commit has multiple item ids: " .. sha end
        else
          if objects[sha] == nil or objects[sha].otype ~= "commit" then
            return nil, "missing source commit " .. sha
          end
          local event, e = parse(sha, ref, id, objects[sha].content)
          if event == nil then return nil, e end
          by_sha[sha] = event
        end
      end
    end
  end
  local out: {Event} = {}
  local ready: {Event} = {}
  local children: {string: {Event}} = {}
  local function earlier(a: Event, b: Event): boolean
    return a.seconds < b.seconds or (a.seconds == b.seconds
      and (a.ref < b.ref or (a.ref == b.ref and a.sha < b.sha)))
  end
  local function enqueue(event: Event)
    local low, high = 1, #ready + 1
    while low < high do
      local mid = (low + high) // 2
      if earlier(ready[mid], event) then low = mid + 1 else high = mid end
    end
    table.insert(ready, low, event)
  end
  for _, event in pairs(by_sha) do
    if event.parent == "" then enqueue(event)
    elseif by_sha[event.parent] == nil then return nil, "source first-parent closure is incomplete"
    else
      children[event.parent] = children[event.parent] or {}
      children[event.parent][#children[event.parent] + 1] = event
    end
  end
  while #ready > 0 do
    local best = table.remove(ready, 1)
    out[#out + 1] = best
    for _, event in ipairs(children[best.sha] or {}) do enqueue(event) end
  end
  return out, ""
end

local record Source
  type Event = Event
  git: function(root: string, args: {string}, input?: string): string | nil, string
  snapshot: function(root: string, prefix: string): {string: string} | nil, string
  compare: function(expected: {string: string}, actual: {string: string}): boolean, string
  integrity: function(root: string, refs: {string: string}): boolean, string
  events: function(root: string, refs: {string: string}, prefix: string): {Event} | nil, string
end
local M: Source = {git = git, snapshot = snapshot, compare = compare,
  integrity = integrity, events = events}
return M
