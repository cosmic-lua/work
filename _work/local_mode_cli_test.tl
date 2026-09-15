#!/usr/bin/env cosmic
local check = require("cosmic.check")
local fixture = require("_work.fixture")
local gitboard = require("_work.gitboard")
local refs = require("_work.refs")
local workspace = require("_work.snapshot_workspace")

local function test_local_mutation_auto_confirms_without_a_snapshot()
  local s = fixture.init_state_repo("local-cli-auto-confirm")
  local before = check.must(refs.read_ref(s.root, "refs/heads/state"))
  assert(gitboard.main("new", "Local auto-confirm", "--dir", s.root) == 0)
  local after = check.must(refs.read_ref(s.root, "refs/heads/state"))
  assert(after ~= before, "the public local-mode mutation advances state")
  assert(workspace.read(s.root) == nil,
    "local mode clears the composed snapshot after immediate confirmation")
end
