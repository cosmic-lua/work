#!/usr/bin/env cosmic
local check = require("cosmic.check")
local child = require("cosmic.child")
local fs = require("cosmic.fs")
local json = require("cosmic.json")
local fixture = require("_work.fixture")
local freeze = require("_work.migrate6_freeze")
local migrate = require("_work.migrate6")
local archive = require("_work.migrate6_archive")
local probes = require("_work.migrate6_probes")
local publish = require("_work.migrate6_publish")
local wire = require("_work.singlehead_literal")
local source = require("_work.migrate6_source")

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

local function init(name: string): string
  local root = fs.join(fixture.tmpdir, name)
  assert(fs.remove_all(root) and fs.make_dirs(root)); fixture.git(root, {"init", "-q"})
  assert(fs.write(fs.join(root, "format"), "5\n")); fixture.git(root, {"add", "format"})
  fixture.git(root, {"commit", "-qm", "freeze base"})
  return root
end

local function simulated(root: string, url: string, path: string): probes.Manifest, {string: string}, probes.Reader
  local state: {string: string} = {}
  local function reader(_root: string, _url: string, refs: {string}): {string: string} | nil, string
    local out: {string: string} = {}
    for _, ref in ipairs(refs) do if state[ref] ~= nil then out[ref] = state[ref] end end
    return out, ""
  end
  local function seed(_root: string, _url: string, args: {string}): boolean, string
    for _, refspec in ipairs(args) do
      local sha, ref = refspec:match("^([0-9a-f]+):(refs/heads/.+)$")
      assert(sha ~= nil and ref ~= nil); state[ref] = sha
    end
    return true, "seeded"
  end
  return check.must(probes.prepare(root, url, path, seed, reader)), state, reader
end

local function rejected(ref: string): string
  return "remote: error: GH013: Repository rule violations found for " .. ref .. ".\n" ..
  " ! [remote rejected] probe -> probe (push declined due to repository rule violations)"
end

local function test_prepare_is_durable_idempotent_and_refuses_moved_or_unowned_refs()
  local root = init("migrate6-prepare")
  local path = fs.join(root, "o/probes.literal")
  local manifest, state, reader = simulated(root, "https://github.com/owner/repo.git", path)
  assert(manifest.status == "seeded" and next(manifest.receipts) ~= nil)
  local function no_push(_root: string, _url: string, _args: {string}): boolean, string
    return false, "must not reseed"
  end
  local resumed = check.must(probes.prepare(root, manifest.destination, path, no_push, reader))
  assert(resumed.name == manifest.name, "resume keeps the write-before-push plan")
  local update = manifest.refs[probes.key("update", probes.namespaces[1])]
  state[update] = manifest.new_sha
  local bad, err = probes.prepare(root, manifest.destination, path, no_push, reader)
  assert(bad == nil and err:find("sacrificial ref moved", 1, true), err)
  state[update] = manifest.old_sha
  local raw: {string: string} = {["refs/x/items/real"] = manifest.old_sha}
  for _, namespace in ipairs(probes.namespaces) do
    for _, kind in ipairs({"update", "delete"}) do
      raw["refs/x/" .. manifest.refs[probes.key(kind, namespace)]:sub(#"refs/heads/" + 1)] = manifest.old_sha
    end
  end
  local filtered = check.must(probes.filter(raw, "refs/x/", manifest))
  assert(filtered["refs/x/items/real"] == manifest.old_sha, "only exact owned probe refs are filtered")
  raw["refs/x/" .. update:sub(#"refs/heads/" + 1)] = manifest.new_sha
  assert(probes.filter(raw, "refs/x/", manifest) == nil, "a moved fetched probe refuses")
end

local function test_prepare_recovers_an_interrupted_partial_seed_from_its_planned_manifest()
  local root = init("migrate6-prepare-interrupted")
  local path, url = fs.join(root, "o/probes.literal"), "https://github.com/owner/repo.git"
  local state: {string: string} = {}
  local function reader(_root: string, _url: string, refs: {string}): {string: string} | nil, string
    local out: {string: string} = {}
    for _, ref in ipairs(refs) do if state[ref] ~= nil then out[ref] = state[ref] end end
    return out, ""
  end
  local function interrupted(_root: string, _url: string, args: {string}): boolean, string
    local planned = check.must(probes.read(path))
    assert(planned.status == "planned" and next(planned.receipts) == nil,
      "the complete plan is durable before its first remote write")
    local sha, ref = args[1]:match("^([0-9a-f]+):(refs/heads/.+)$")
    assert(sha ~= nil and ref ~= nil); state[ref] = sha
    return false, "connection lost after one ref"
  end
  local first, err = probes.prepare(root, url, path, interrupted, reader)
  assert(first == nil and err:find("cannot seed", 1, true), err)
  local function finish(_root: string, _url: string, args: {string}): boolean, string
    for _, refspec in ipairs(args) do
      local sha, ref = refspec:match("^([0-9a-f]+):(refs/heads/.+)$")
      assert(sha ~= nil and ref ~= nil); state[ref] = sha
    end
    return true, ""
  end
  local recovered = check.must(probes.prepare(root, url, path, finish, reader))
  assert(recovered.status == "seeded" and next(recovered.receipts) ~= nil)
end

local function test_freeze_observes_probes_fetch_and_binds_destination_and_refset()
  local root = init("migrate6-freeze")
  local url = "https://github.com/owner/repo.git"
  fixture.git(root, {"remote", "add", "origin", url})
  local manifest, state, reader = simulated(root, url, fs.join(root, "o/probes.literal"))
  local steps: {string} = {}
  local function provider(repo: string, id: integer): string | nil, string
    assert(repo == "owner/repo" and id == 12); steps[#steps + 1] = "observe"; return response(), ""
  end
  local function pusher(_root: string, _url: string, args: {string}): boolean, string
    if steps[#steps] ~= "probe" then steps[#steps + 1] = "probe" end
    local ref = args[#args]:match(":(refs/heads/.+)$")
    assert(ref ~= nil)
    return false, rejected(ref)
  end
  local function fetcher(fetch_root: string, _url: string, prefix: string): boolean, string
    assert(table.concat(steps, ",") == "observe,probe")
    steps[#steps + 1] = "fetch"
    local head = check.must(source.git(fetch_root, {"rev-parse", "HEAD"})):gsub("%s+$", "")
    check.must(source.git(fetch_root, {"update-ref", prefix .. "items/real", head}))
    for ref, sha in pairs(state) do
      check.must(source.git(fetch_root, {"update-ref", prefix .. ref:sub(#"refs/heads/" + 1), sha}))
    end
    return true, ""
  end
  local snap = check.must(freeze.snapshot(root, "origin", 12, manifest,
      provider, fetcher, nil, pusher, reader))
  assert(table.concat(steps, ",") == "observe,probe,fetch,observe")
  assert(snap.sources[snap.proof.prefix .. "items/real"] ~= nil)
  for ref in pairs(snap.sources) do assert(not ref:find(manifest.name, 1, true), ref) end
  assert(freeze.verify(root, "origin", snap.proof, snap.sources, provider, pusher, reader))
  local repository = check.must(source.git(root, {"rev-parse", "--absolute-git-dir"})):gsub("%s+$", "")
  local checkpoint: migrate.Checkpoint = {version = "migrate6-v2", repository = repository,
    snapshot_at = snap.proof.after.observed_at, phase = "frozen", prefix = snap.proof.prefix,
    sources = snap.sources, marks = {}, head = "", replayed_head = "", activation = "",
    count = 0, freeze = snap.proof}
  local checkpoint_path = fs.join(root, "o/serialized-checkpoint.literal")
  assert(fs.write(checkpoint_path, check.must(wire.encode(checkpoint)), {atomic = true}))
  local loaded = check.must(migrate.read(checkpoint_path))
  assert(loaded.freeze.probes.refs[probes.key("update", probes.namespaces[1])] ==
    manifest.refs[probes.key("update", probes.namespaces[1])])
  assert(migrate.validate_sources(root, loaded),
    "serialized exclusions survive the later source/fsck guard")
  local moved_ref = snap.proof.prefix .. manifest.refs[probes.key("update", probes.namespaces[1])]:sub(#"refs/heads/" + 1)
  check.must(source.git(root, {"update-ref", moved_ref, manifest.new_sha}))
  assert(not migrate.validate_sources(root, loaded), "a moved serialized exclusion refuses")
  check.must(source.git(root, {"update-ref", moved_ref, manifest.old_sha}))
  local changed = {[snap.proof.prefix .. "items/real"] = string.rep("a", 40)}
  assert(not freeze.verify(root, "origin", snap.proof, changed, provider, pusher, reader))
  fixture.git(root, {"remote", "set-url", "--push", "origin", "https://github.com/owner/repo"})
  assert(not freeze.verify(root, "origin", snap.proof, snap.sources, provider, pusher, reader),
    "exact push destination is bound")
end

local function test_probe_uses_existing_distinct_refs_and_rejects_auth_or_missing_ref_failures()
  local root = init("migrate6-probe-frozen")
  local manifest, state, reader = simulated(root, "https://github.com/owner/repo.git",
    fs.join(root, "o/probes.literal"))
  local seen: {string} = {}
  local function frozen(_root: string, _url: string, args: {string}): boolean, string
    seen[#seen + 1] = table.concat(args, " ")
    local ref = args[#args]:match(":(refs/heads/.+)$")
    assert(ref ~= nil)
    return false, rejected(ref)
  end
  local refusals = check.must(freeze.probe(root, manifest.destination, manifest, frozen, reader))
  local recorded = 0; for _ in pairs(refusals) do recorded = recorded + 1 end
  assert(recorded == 9 and #seen == 9)
  local all = table.concat(seen, "\n")
  assert(all:find("--force " .. manifest.new_sha .. ":", 1, true), "update uses the distinct commit")
  local function auth(_root: string, _url: string, _args: {string}): boolean, string
    return false, "fatal: Authentication failed"
  end
  local failed, err = freeze.probe(root, manifest.destination, manifest, auth, reader)
  assert(failed == nil and err:find("did not prove a GitHub ruleset refusal", 1, true), err)
  local missing = manifest.refs[probes.key("delete", probes.namespaces[1])]
  state[missing] = nil
  failed, err = freeze.probe(root, manifest.destination, manifest, frozen, reader)
  assert(failed == nil and err:find("missing or moved", 1, true), err)
end

local function test_open_destination_is_restored_after_an_accepted_create_probe()
  local root = init("migrate6-probe-open")
  local remote = fs.join(fixture.tmpdir, "migrate6-probe-open.git")
  assert(fs.remove_all(remote)); fixture.git(fixture.tmpdir, {"clone", "--bare", "-q", root, remote})
  local manifest = check.must(probes.prepare(root, remote, fs.join(root, "o/probes.literal"), nil, nil))
  local refused, err = freeze.probe(root, remote, manifest, nil, nil)
  assert(refused == nil and err:find("does not refuse create", 1, true), err)
  local listed = check.must(child.run({"git", "for-each-ref", "--format=%(refname)", "refs/heads/"}, {cwd = remote}))
  assert(listed.ok and not listed.stdout:find(manifest.refs[probes.key("create", probes.namespaces[1])], 1, true),
    "accepted creation is removed before refusal")
end

local function test_activation_source_check_requires_exact_probe_and_legacy_refs()
  local root = init("migrate6-activation-probes")
  local head = check.must(source.git(root, {"rev-parse", "HEAD"})):gsub("%s+$", "")
  fixture.git(root, {"update-ref", "refs/heads/items/real", head})
  local remote = fs.join(fixture.tmpdir, "migrate6-activation-probes.git")
  assert(fs.remove_all(remote)); fixture.git(fixture.tmpdir, {"clone", "--bare", "-q", root, remote})
  fixture.git(root, {"remote", "add", "origin", remote})
  local manifest = check.must(probes.prepare(root, remote, fs.join(root, "o/probes.literal"), nil, nil))
  local observation = check.must(freeze.inspect(response(), remote, "owner/repo", 12))
  local proof: freeze.Proof = {before = observation, after = observation,
    prefix = "refs/review/", source_digest = string.rep("a", 64), probes = manifest, refusals = {}}
  local cp: migrate.Checkpoint = {version = "migrate6-v2", repository = root,
    snapshot_at = observation.observed_at, phase = "frozen", prefix = "refs/review/",
    sources = {["refs/review/items/real"] = head}, marks = {}, head = "",
    replayed_head = "", activation = "", count = 0, freeze = proof}
  local verified, verify_err = publish.verify_sources(root, cp, "origin")
  assert(verified ~= nil, "all source and prepared refs are exact: " .. verify_err)
  local raw = check.must(archive.build(cp.sources, cp.prefix, manifest))
  local witness = check.must(archive.decode(raw))
  assert(witness.probe_name == manifest.name)
  for _, namespace in ipairs(probes.namespaces) do
    assert(witness.refs[manifest.refs[probes.key("update", namespace)]] == manifest.old_sha)
    assert(witness.refs[manifest.refs[probes.key("delete", namespace)]] == manifest.old_sha)
    assert(witness.absent[manifest.refs[probes.key("create", namespace)]] == "absent")
  end
  assert(#archive.problems(remote, raw, "refs/heads/") == 0)
  local update = manifest.refs[probes.key("update", probes.namespaces[1])]
  check.must(source.git(root, {"push", remote, manifest.new_sha .. ":refs/scratch/probe-moved"}))
  fixture.git(remote, {"update-ref", "-d", "refs/scratch/probe-moved"})
  fixture.git(remote, {"update-ref", update, manifest.new_sha})
  local moved = table.concat(archive.problems(remote, raw, "refs/heads/"), "\n")
  assert(moved:find("archive: moved " .. update, 1, true))
  local actual, err = publish.verify_sources(root, cp, "origin")
  assert(actual == nil and err:find("moved", 1, true), err)
  fixture.git(remote, {"update-ref", update, manifest.old_sha})
  fixture.git(remote, {"update-ref", "refs/heads/items/unexpected", head})
  local added = table.concat(archive.problems(remote, raw, "refs/heads/"), "\n")
  assert(added:find("archive: added refs/heads/items/unexpected", 1, true))
  actual, err = publish.verify_sources(root, cp, "origin")
  assert(actual == nil and err:find("added refs/heads/items/unexpected", 1, true), err)
end
