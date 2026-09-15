#!/usr/bin/env cosmic
local check = require("cosmic.check")
local json = require("cosmic.json")
local fixture = require("_work.fixture")
local cli = require("_work.statepublish_cli")
local publication = require("_work.snapshot_publish")
local store = require("_work.store")
local write = require("_work.storewrite")

local function capture(f: function(): integer): integer, string
  local old_print = _G.print
  local lines: {string} = {}
  _G.print = function(...: any)
    local parts: {string} = {}
    for i = 1, select("#", ...) do
      parts[i] = tostring((select(i, ...)))
    end
    lines[#lines + 1] = table.concat(parts, "\t")
  end
  local ok, result = pcall(f)
  _G.print = old_print
  if not ok then error(result, 0) end
  -- cast: pcall erases the callee's integer return type
  return result as integer, table.concat(lines, "\n")
end

local function test_begin_emits_early_machine_outcomes()
  local s = fixture.init_state_repo("statepublish-early-outcome")
  local _, id = fixture.root_with_leaf(s)
  local it = check.must(store.load(s, id)); it.title = "early outcome"
  write.set_session(s, "holder")
  assert(write.save(s, it, "early outcome"))
  local commit = check.must(require("_work.snapshot_workspace").read(s.root)).commit
  local planned = check.must(publication.plan(s.root, commit, "origin", nil))
  local original = publication.begin_plan
  for _, status in ipairs({"uncertain", "conflict"}) do
    publication.begin_plan = function(_root: string, _commit: string,
        _remote: string, _now?: integer): publication.Planned | nil, string
      return planned, status .. ": exact destination outcome"
    end
    local code, out = capture(function(): integer
        return cli.protocol(s, commit, "origin", "begin", "", "", "", nil)
      end)
    local decoded = check.must(json.decode_object(out))
    assert(code == 0 and decoded.status == status
      and decoded.reason == "exact destination outcome", out)
  end
  publication.begin_plan = original
end
