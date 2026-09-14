#!/usr/bin/env cosmic
-- This module is now only the explicit caller-owned process boundary.
local check = require("cosmic.check")
local fixture = require("_work.fixture")
local prepared = require("_work.prepared")

local function test_execute_reports_process_success_and_failure()
  local s = fixture.init_state_repo("prepared-execute")
  local ok, err = prepared.execute(s.root, {"git", "rev-parse", "--git-dir"})
  assert(ok and err == "")
  ok, err = prepared.execute(s.root, {"git", "rev-parse", "--verify",
      "refs/heads/does-not-exist"})
  assert(not ok and err ~= "")
  assert(check.must(prepared.execute(s.root, {"git", "status",
          "--porcelain"})) == true)
end
