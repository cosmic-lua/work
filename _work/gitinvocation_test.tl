#!/usr/bin/env cosmic
-- The GitBoard invocation prefix a brief renders: an exact, working
-- `cd <cwd> && <command>` when the caller supplied both, an explicit
-- sentinel — never a guessed `bin/gitboard` — when they did not.

local gitinvocation = require("_work.gitinvocation")

local function test_resolved_prefix_is_cd_and_command()
  local out = gitinvocation.prefix("sh /board/o/bin/gitboard", "/orchestrator/run")
  assert(out == "cd /orchestrator/run && sh /board/o/bin/gitboard", out)
end

local function test_unresolved_is_an_explicit_sentinel_not_bin_gitboard()
  local out = gitinvocation.prefix("", "")
  assert(out == gitinvocation.UNRESOLVED, out)
  assert(out:find("bin/gitboard", 1, true) == nil,
    "the fallback never guesses a product-checkout bin/gitboard: " .. out)
  assert(out:find("UNRESOLVED", 1, true) ~= nil,
    "the fallback labels itself unresolved: " .. out)
end
