#!/usr/bin/env cosmic
-- Caller-owned transport around a real overlapping claim-batch race.
local check = require("cosmic.check")
local claimsession = require("_work.claimsession")
local fixture = require("_work.fixture")
local gitboard = require("_work.gitboard")
local gitclaim = require("_work.gitclaim")
local prepared = require("_work.prepared")
local refs = require("_work.refs")
local store = require("_work.store")

local function capture(...: string): integer, string
  local old_print = _G.print
  local lines: {string} = {}
  _G.print = function(...: any)
    local parts: {string} = {}
    for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
    lines[#lines + 1] = table.concat(parts, "\t")
  end
  local ok, code = pcall(gitboard.main, ...)
  _G.print = old_print
  if not ok then error(code, 0) end
  return code, table.concat(lines, "\n")
end

local function prepare_set(s: store.Store, ids: {string}, batch: string,
    caller: string): gitclaim.Prepared
  local requests: {gitclaim.Request} = {}
  for _, id in ipairs(ids) do
    requests[#requests + 1] = {root = s.root, id = id, remote = "origin",
      source_ref = gitclaim.remote_item_ref("origin", id),
      target_ref = gitclaim.target_item_ref(id), batch = batch, caller = caller,
      action = "take", product_base = ("a"):rep(40), force = false, why = "",
      now = os.time()}
  end
  local result = gitclaim.prepare_batch(requests)
  assert(next(result.refused) == nil, result.refused.batch or "claim refused")
  return check.must(result.prepared)
end

local function remote_snapshot(s: store.Store): string
  return check.must(store.git_ok(s, {"ls-remote", "origin"})).stdout
end

local function offline_capture(...: string): integer, string
  local execute = prepared.execute
  prepared.execute = function(_root: string, _argv: {string}): boolean, string
    error("render-only public flow attempted transport")
  end
  local ok, code, output = pcall(capture, ...)
  prepared.execute = execute
  if not ok then error(code, 0) end
  return code, output
end

local function test_lost_batch_is_reported_once_and_stops_blocking_publish()
  local a_side, b_side = fixture.init_shared("cli-quarantine-overlap")
  local a = fixture.file_item(a_side, "overlap a", "")
  local b = fixture.file_item(a_side, "overlap b", "")
  local c = fixture.file_item(a_side, "uncontested c", "")
  local d = fixture.file_item(a_side, "fresh d", "")
  fixture.caller_fetch(b_side)
  local alice, bob = claimsession.mint(), claimsession.mint()
  local winner = prepare_set(a_side, {a, b}, "quarantine-winner", alice)
  local loser = prepare_set(b_side, {b, c}, "quarantine-loser", bob)
  assert(prepared.execute(a_side.root, prepared.push_argv(winner.transaction)))
  local pushed = prepared.execute(b_side.root, prepared.push_argv(loser.transaction))
  assert(not pushed, "the overlapping atomic batch must lose")
  local snapshot = remote_snapshot(b_side)
  assert(not snapshot:find(loser.batch.commit, 1, true),
    "a rejected batch must not leak its append-only ref")
  assert(prepared.execute(b_side.root, prepared.fetch_argv()))
  assert(store.close(b_side))

  local destination = "refs/gitboard/quarantined/lost-race/" .. loser.transaction.id
  local code, output = offline_capture("refresh", "--dir", b_side.root)
  assert(code == 1 and output:find("lost-race", 1, true), output)
  assert(output:find(destination, 1, true), output)
  assert(output:find("no claim authority confirmed", 1, true), output)
  assert(check.must(refs.read_ref(b_side.root, destination)) == loser.transaction.manifest)
  assert(check.must(refs.read_ref(b_side.root, loser.transaction.staging_ref)) == refs.ZERO_SHA)
  local loaded = check.must(store.load(b_side, b))
  assert(loaded.claim_batch == winner.batch.commit,
    "quarantining a loser must not replace the winner's authority")

  code, output = offline_capture("refresh", "--dir", b_side.root)
  assert(code == 0 and output:find("lost-race=0", 1, true), output)
  assert(not output:find(loser.id, 1, true), "a quarantined loss must not repeat")
  local fresh = prepare_set(b_side, {c}, "quarantine-fresh", bob)
  code, output = offline_capture("publish", "--dir", b_side.root)
  assert(code == 0 and output:find(fresh.batch.commit, 1, true), output)
  assert(not output:find(loser.batch.commit, 1, true), output)
  assert(output:find("nothing executed", 1, true), output)
  for _, selector in ipairs({loser.id, loser.transaction.id, destination}) do
    code, output = offline_capture("publish", selector, "--dir", b_side.root)
    assert(code == 1, "quarantine must not remain selectable: " .. output)
  end
  local another = prepare_set(b_side, {d}, "quarantine-another", bob)
  assert(another.id ~= fresh.id)
  code, output = offline_capture("publish", "--dir", b_side.root)
  assert(code == 1 and output:find("select exactly one", 1, true), output)
  assert(remote_snapshot(b_side) == snapshot,
    "local reconciliation and rendered publication must never move remote refs")
end
