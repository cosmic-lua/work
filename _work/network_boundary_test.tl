#!/usr/bin/env cosmic
-- Static guard for the credential/provider boundary. Ordinary Git
-- transport may exist behind an explicit execution choice elsewhere;
-- this test protects the two accidental in-process paths that made
-- gitboard depend on the ambient environment: GitHub credentials in
-- the REST codec and implicit fetches during worktree provisioning.
--
-- Every source below is read as TEXT, so the build graph cannot see
-- that this test depends on it; the declaration re-records the result
-- when one of them changes. Without it an edit to a guarded file
-- replays the last recorded pass and the guard reads as decoration.
--- reads: _work cmd

local fs = require("cosmic.fs")

local function source(path: string): string
  local text, err = fs.read(path)
  assert(text ~= nil, ("read %s: %s"):format(path, tostring(err)))
  return text
end

local api = source("_work/api.tl")
assert(api:find('require("cosmic.env")', 1, true) == nil,
  "the provider codec must not inspect ambient authentication or proxy state")
assert(api:find('env.get("GITHUB_TOKEN")', 1, true) == nil
  and api:find('env.get("GH_TOKEN")', 1, true) == nil,
  "gitboard must not discover GitHub credentials")
assert(api:find("transport = fetch.fetch", 1, true) == nil,
  "the production provider transport must remain disabled")

local worktree = source("_work/gitworktree.tl")
assert(worktree:find('{"git", "fetch"', 1, true) == nil,
  "worktree preparation consumes caller-fetched refs; it never fetches")
assert(worktree:find('{"bin/cosmic", "--make", "fetch"', 1, true) == nil,
  "worktree bootstrap builds only from caller-prepared dependencies")

for _, path in ipairs({"_work/storeinit.tl", "_work/format.tl"}) do
  local init_source = source(path)
  assert(init_source:find('"push", "origin"', 1, true) == nil,
    path .. " must prepare local objects and refs without publishing")
end

local take = source("_work/gittake.tl")
assert(take:find('require("_work.gh")', 1, true) == nil
  and take:find('"ls-remote"', 1, true) == nil,
  "take --open renders a caller action; it neither probes nor writes GitHub")

-- A live transport has exactly one way in: `_work/apiauth.tl`, which a
-- caller requires by name and hands the NAME of the variable holding
-- its token. Two properties keep that explicit. The opt-in never names
-- a credential variable itself, so gitboard cannot pick one up by
-- guessing; and no source in the binary reaches the opt-in except the
-- one allowed call site below, so requiring any other module still
-- installs the local refusal and nothing else.
local apiauth = source("_work/apiauth.tl")
assert(apiauth:find("GITHUB_TOKEN", 1, true) == nil
  and apiauth:find("GH_TOKEN", 1, true) == nil,
  "the opt-in reads the variable its caller names; it never guesses one")

-- Exhaustive rather than enumerated: an allow-list of files that may
-- reach the opt-in, checked against every Teal source that ships in
-- gitboard. An enumeration of guarded files protects only the files
-- someone thought to name, and the ones that matter most — the
-- binary's entry and the dispatcher every verb loads — are exactly the
-- ones a later reader is least likely to add, since either of them
-- activating would hand every verb a live transport with nothing here
-- tripping.
local ALLOWED_TO_ACTIVATE: {string: boolean} = {
  -- The opt-in's own tests.
  ["_work/apiauth_test.tl"] = true,
  -- The one call site: the landing an accepted verdict performs,
  -- which installs a transport for that step and takes it down again.
  ["_work/ghland.tl"] = true,
}

-- Assembled rather than written out, so this file does not itself
-- contain the string it searches for and needs no exemption of its own.
local ACTIVATES < const > = ('require("_work.%s")'):format("apiauth")

local function guarded_sources(): {string}
  local paths: {string} = {}
  -- Recursive on purpose. `_work` has no subdirectories today, but the
  -- module root is the repository root, so a later `_work/<sub>/x.tl`
  -- would ship in the binary as `_work.<sub>.x` like any other source
  -- — and a top-level-only walk would leave it unguarded without
  -- anything here saying so.
  local work = fs.find("_work", {glob = "*.tl", sorted = true})
  assert(work ~= nil, "listing _work")
  local commands = fs.find("cmd", {glob = "*.tl", sorted = true})
  assert(commands ~= nil, "listing cmd")
  for _, found in ipairs({work, commands}) do
    for _, path in ipairs(found) do
      paths[#paths + 1] = path
    end
  end
  assert(#paths > 1, "the walk found nothing to guard")
  return paths
end

local guarded = guarded_sources()
local seen_entry = false
local seen_dispatcher = false
for _, path in ipairs(guarded) do
  if path == "cmd/gitboard/main.tl" then seen_entry = true end
  if path == "_work/gitboard.tl" then seen_dispatcher = true end
  if not ALLOWED_TO_ACTIVATE[path] then
    assert(source(path):find(ACTIVATES, 1, true) == nil,
      path .. " must not activate the provider transport")
  end
end
assert(seen_entry, "the walk missed the binary's entry point")
assert(seen_dispatcher, "the walk missed the verb dispatcher")
