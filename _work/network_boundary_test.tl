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
--- reads: _work/api.tl _work/apiauth.tl _work/gitworktree.tl _work/storeinit.tl _work/format.tl _work/gittake.tl

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
-- guessing; and nothing on the codec's own load path, nor any verb
-- guarded above, reaches the opt-in, so requiring any of them still
-- installs the local refusal and nothing else.
local apiauth = source("_work/apiauth.tl")
assert(apiauth:find("GITHUB_TOKEN", 1, true) == nil
  and apiauth:find("GH_TOKEN", 1, true) == nil,
  "the opt-in reads the variable its caller names; it never guesses one")

for _, path in ipairs({"_work/api.tl", "_work/gittake.tl",
    "_work/gitworktree.tl", "_work/storeinit.tl", "_work/format.tl"}) do
  assert(source(path):find('require("_work.apiauth")', 1, true) == nil,
    path .. " must not activate the provider transport")
end
