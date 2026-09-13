#!/usr/bin/env cosmic
local check = require("cosmic.check")
local child = require("cosmic.child")
local fs = require("cosmic.fs")
local json = require("cosmic.json")
local fixture = require("_work.fixture")
local freeze = require("_work.migrate6_freeze")

local function response(date?: string, change?: string): string
  local body: {string: any} = {id = 12, target = "branch", enforcement = "active", source_type = "Repository",
    source = "owner/repo", updated_at = "2026-09-13T10:00:00Z", bypass_actors = {},
    conditions = {ref_name = {include = {"refs/heads/items/**", "refs/heads/ended/**",
          "refs/heads/claim-batches/**", "refs/heads/board/seq"}, exclude = {}}},
    rules = {{type = "creation"}, {type = "update", parameters = {update_allows_fetch_and_merge = false}}, {type = "deletion"}}}
  if change == "missing-bypass" then body.bypass_actors = nil end
  if change == "disabled" then body.enforcement = "disabled" end
  if change == "new-update" then body.updated_at = "2026-09-13T10:00:01Z" end
  return "HTTP/2.0 200 OK\r\nDate: " .. (date or "Sun, 13 Sep 2026 10:00:02 GMT") .. "\r\n\r\n" .. check.must(json.encode(body))
end

local function test_freeze_rejects_missing_access_and_changed_or_reordered_observations()
  local url = "git@github.com:owner/repo.git"
  local before = check.must(freeze.inspect(response(), url, "owner/repo", 12))
  assert(freeze.inspect(response(nil, "missing-bypass"), url, "owner/repo", 12) == nil)
  assert(freeze.inspect(response(nil, "disabled"), url, "owner/repo", 12) == nil)
  local changed = check.must(freeze.inspect(response(nil, "new-update"), url, "owner/repo", 12))
  assert(not freeze.brackets(before, changed), "a changed ruleset cannot attest the earlier snapshot")
  local earlier = check.must(freeze.inspect(response("Sun, 13 Sep 2026 10:00:01 GMT"), url, "owner/repo", 12))
  assert(not freeze.brackets(before, earlier), "server observations must bracket fetch in order")
  assert(freeze.repository("https://elsewhere.test/owner/repo.git") == nil)
end

local function test_freeze_observes_before_fresh_fetch_and_binds_destination_and_refset()
  local root = fs.join(fixture.tmpdir, "migrate6-freeze")
  assert(fs.remove_all(root)); assert(fs.make_dirs(root)); fixture.git(root, {"init", "-q"})
  assert(fs.write(fs.join(root, "format"), "5\n"))
  fixture.git(root, {"add", "format"})
  fixture.git(root, {"commit", "-qm", "freeze base"})
  fixture.git(root, {"remote", "add", "origin", "https://github.com/owner/repo.git"})
  local steps: {string} = {}
  local function provider(repo: string, id: integer): string | nil, string
    assert(repo == "owner/repo" and id == 12)
    steps[#steps + 1] = "observe"
    return response(), ""
  end
  local function pusher(_root: string, url: string, _args: {string}): boolean, string
    assert(url == "https://github.com/owner/repo.git")
    if steps[#steps] ~= "probe" then steps[#steps + 1] = "probe" end
    return false, "remote rejected: protected by ruleset"
  end
  local function fetcher(_root: string, url: string, prefix: string): boolean, string
    assert(table.concat(steps, ",") == "observe,probe",
      "the freeze must be observed AND proven before fresh source acquisition")
    assert(url == "https://github.com/owner/repo.git" and prefix:match("^refs/gitboard/migrate6/source%-"))
    steps[#steps + 1] = "fetch"
    return true, ""
  end
  local snap = check.must(freeze.snapshot(root, "origin", 12, provider, fetcher, nil, pusher))
  assert(table.concat(steps, ",") == "observe,probe,fetch,observe")
  assert(freeze.verify(root, "origin", snap.proof, snap.sources, provider, pusher))
  local changed = {[snap.proof.prefix .. "items/a"] = string.rep("a", 40)}
  assert(not freeze.verify(root, "origin", snap.proof, changed, provider, pusher), "snapshot source digest is immutable")
  -- Another exact URL for the SAME repository, differing only in its `.git`
  -- suffix: the witness binds the destination git will actually push to, so a
  -- rewritten spelling of it is still a different destination. An `ssh://` or
  -- `git@` spelling would not do here — ambient `url.*.insteadOf`
  -- configuration (which `GIT_CONFIG_PARAMETERS` can carry past an empty
  -- global config) collapses those onto the https form.
  fixture.git(root, {"remote", "set-url", "--push", "origin", "https://github.com/owner/repo"})
  assert(freeze.destination(root, "origin") == "https://github.com/owner/repo",
    "the fixture's push destination is the one this case binds against")
  assert(not freeze.verify(root, "origin", snap.proof, snap.sources, provider, pusher),
    "exact push destination is bound")
end

-- The probe proves the fence BITES. A destination with no ruleset accepts the
-- throwaway create, which disproves the freeze — and the probe cleans up the
-- ref it just proved it could make rather than leaving it on a live board.
local function test_freeze_probe_refuses_a_destination_that_accepts_a_legacy_write()
  local root = fs.join(fixture.tmpdir, "migrate6-probe-open")
  local remote = fs.join(fixture.tmpdir, "migrate6-probe-open.git")
  assert(fs.remove_all(root) and fs.remove_all(remote) and fs.make_dirs(root))
  fixture.git(root, {"init", "-q"})
  assert(fs.write(fs.join(root, "format"), "5\n"))
  fixture.git(root, {"add", "format"})
  fixture.git(root, {"commit", "-qm", "probe base"})
  fixture.git(fixture.tmpdir, {"clone", "--bare", "-q", root, remote})
  local refused, err = freeze.probe(root, remote)
  assert(refused == nil and err:find("does not refuse create of refs/heads/items/", 1, true) ~= nil, err)
  assert(err:find("the probe ref remains", 1, true) == nil, "an accepted probe ref is deleted again: " .. err)
  local left = check.must(child.run({"git", "for-each-ref", "--format=%(refname)", "refs/heads/items/"},
      {cwd = remote}))
  assert(left.ok and left.stdout == "", "the probe left a ref behind: " .. left.stdout)
end

-- Every attempt a frozen destination refuses is recorded with its own text, so
-- the checkpoint carries what was actually proven rather than a boolean.
local function test_freeze_probe_records_every_refused_attempt()
  local root = fs.join(fixture.tmpdir, "migrate6-probe-frozen")
  assert(fs.remove_all(root) and fs.make_dirs(root))
  fixture.git(root, {"init", "-q"})
  assert(fs.write(fs.join(root, "format"), "5\n"))
  fixture.git(root, {"add", "format"})
  fixture.git(root, {"commit", "-qm", "probe base"})
  local seen: {string} = {}
  local function pusher(_root: string, _url: string, args: {string}): boolean, string
    seen[#seen + 1] = table.concat(args, " ")
    return false, "remote rejected: protected by ruleset"
  end
  local refusals = check.must(freeze.probe(root, root, pusher))
  local recorded = 0
  for attempt, detail in pairs(refusals) do
    assert(detail == "remote rejected: protected by ruleset", attempt)
    recorded = recorded + 1
  end
  assert(recorded == 9 and #seen == 9, "three attempts in each of three namespaces: " .. recorded)
  assert(table.concat(seen, "\n"):find("--force", 1, true) ~= nil, "a forced update is attempted too")
end
