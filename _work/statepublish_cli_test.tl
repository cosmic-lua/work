#!/usr/bin/env cosmic
local check = require("cosmic.check")
local child = require("cosmic.child")
local fs = require("cosmic.fs")
local fixture = require("_work.fixture")
local cli = require("_work.statepublish_cli")
local stateinit = require("_work.stateinit")
local store = require("_work.store")

local function test_obsolete_saved_transaction_plan_refuses_explicitly()
  local root = fs.join(fixture.tmpdir, "obsolete-state-plan")
  assert(fs.remove_all(root) and fs.make_dirs(root))
  assert(stateinit.init(root))
  assert(check.must(child.run({"git", "config", "gitboard.mode", "local"},
        {cwd = root})).ok)
  local s = check.must(store.open(root))
  assert(cli.cmd_publish(s, {}, "origin", false, "old-format6.literal") == 1)
end
