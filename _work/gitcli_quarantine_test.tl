#!/usr/bin/env cosmic
-- CLI reconciliation around a real overlapping native-state claim race.
local check = require("cosmic.check")
local claimsession = require("_work.claimsession")
local fixture = require("_work.fixture")
local gitboard = require("_work.gitboard")
local prepared = require("_work.prepared")
local refs = require("_work.refs")
local stateclaim = require("_work.stateclaim")
local statepublish = require("_work.statepublish")
local staging = require("_work.statestaging")
local statewrite = require("_work.statewrite")
local store = require("_work.store")

local function capture(...: string): integer, string
  local old_print = _G.print
  local lines: {string} = {}
  _G.print = function(...: any)
    local parts: {string} = {}
    for i = 1, select("#", ...) do
      parts[i] = tostring((select(i, ...)))
    end
    lines[#lines + 1] = table.concat(parts, "\t")
  end
  local ok, code = pcall(gitboard.main, ...)
  _G.print = old_print
  if not ok then error(code, 0) end
  return code, table.concat(lines, "\n")
end

local function prepare_set(s: store.Store, ids: {string},
    holder: string): staging.Receipt
  local requests: {stateclaim.Request} = {}
  for _, id in ipairs(ids) do
    check.must(store.load(s, id))
    requests[#requests + 1] = {id = id, product_base = s.state_head}
  end
  local result = stateclaim.prepare(s.root, s.state_head, requests, "take",
    holder, os.time(), false, "")
  assert(next(result.refused) == nil)
  for _, dependency in ipairs(result.dependencies) do
    s.state_paths[dependency.path], s.state_reads[dependency.path] =
    dependency.id, dependency.id
  end
  assert(statewrite.transition(s, result.changes, "overlapping claim",
      result.publish_by))
  return check.must(staging.load(s.root, s.state_receipt))
end

local function test_lost_claim_is_reported_once_and_stops_blocking_publish()
  local winner_side, loser_side = fixture.init_shared("cli-native-overlap")
  local a = fixture.file_item(winner_side, "overlap a", "")
  local b = fixture.file_item(winner_side, "overlap b", "")
  local c = fixture.file_item(winner_side, "uncontested c", "")
  fixture.caller_fetch(loser_side)
  local winner = prepare_set(winner_side, {a, b}, claimsession.mint())
  local loser = prepare_set(loser_side, {b, c}, claimsession.mint())
  assert(statepublish.execute(winner_side.root, winner))
  assert(prepared.execute(loser_side.root,
      statepublish.fetch_argv(refs.board_remote(loser_side.root))))

  local destination = "refs/gitboard/quarantined/lost-race/" .. loser.id
  local code, output = capture("refresh", "--dir", loser_side.root)
  assert(code == 1 and output:find("lost the push race", 1, true), output)
  assert(check.must(refs.read_ref(loser_side.root, destination)) == loser.sha)
  assert(check.must(refs.read_ref(loser_side.root, loser.ref)) == refs.ZERO_SHA)

  code, output = capture("refresh", "--dir", loser_side.root)
  assert(code == 0 and output:find("lost%-race") == nil, output)
  code, output = capture("publish", loser.id, "--dir", loser_side.root)
  assert(code == 1, "retired receipt must not remain selectable: " .. output)
end
