#!/usr/bin/env cosmic
-- `_work/fixture.tl`'s `git()` helper retries a `git worktree add` that
-- fails with git's own transient `.git/worktrees/<name>/locked` ENOENT
-- race (see the comment above `git()` for the CI evidence). These cases
-- stub `child.run` to reproduce the exact failure text without spawning
-- real git processes or trying to provoke the race itself.
local child = require("cosmic.child")
local fixture = require("_work.fixture")

local LOCKED_STDERR < const > =
"fatal: could not open '.git/worktrees/target/locked' for writing: " ..
"No such file or directory\n"

--- Run `body` with `child.run` replaced by `stub`, restoring the real
--- function afterward even if `body` throws.
local function stubbed(stub: function({string}, child.Options): child.Result | nil, string,
    body: function())
  local original = child.run
  child.run = stub
  local ok, err = pcall(body)
  child.run = original
  if not ok then error(err, 0) end
end

--- Whether `full` (the prefixed argv `git()` actually spawns) is a
--- `git worktree add` call.
local function is_worktree_add(full: {string}): boolean
  for i = 1, #full - 1 do
    if full[i] == "worktree" and full[i + 1] == "add" then
      return true
    end
  end
  return false
end

local function ok_result(): child.Result
  return {code = 0, signal = 0, ok = true, stdout = "", stderr = "", io_error = ""}
end

local function fail_result(stderr: string): child.Result
  return {code = 128, signal = 0, ok = false, stdout = "", stderr = stderr, io_error = ""}
end

local function test_worktree_add_retries_the_locked_race_and_recovers()
  local attempts = 0
  stubbed(function(full: {string}, _opts?: child.Options): child.Result | nil, string
      if is_worktree_add(full) then
        attempts = attempts + 1
        if attempts < 3 then
          return fail_result(LOCKED_STDERR)
        end
      end
      return ok_result()
    end, function()
      fixture.git(fixture.tmpdir, {"worktree", "add", "-q", "--detach", "/tmp/target", "HEAD"})
    end)
  assert(attempts == 3, "expected two retries before success, got " .. attempts .. " attempts")
end

local function test_worktree_add_fails_immediately_on_an_unrelated_message()
  local attempts = 0
  local ok, err = pcall(stubbed,
    function(full: {string}, _opts?: child.Options): child.Result | nil, string
      if is_worktree_add(full) then
        attempts = attempts + 1
        return fail_result("fatal: some unrelated worktree add failure\n")
      end
      return ok_result()
    end, function()
      fixture.git(fixture.tmpdir, {"worktree", "add", "-q", "--detach", "/tmp/target", "HEAD"})
    end)
  assert(not ok, "an unrelated worktree add failure must not be swallowed")
  assert(tostring(err):find("some unrelated worktree add failure", 1, true) ~= nil, tostring(err))
  assert(attempts == 1, "expected exactly one attempt, got " .. attempts .. " attempts")
end

local function test_other_git_subcommands_are_never_retried()
  local attempts = 0
  local ok, err = pcall(stubbed,
    function(full: {string}, _opts?: child.Options): child.Result | nil, string
      for i = 1, #full do
        if full[i] == "status" then
          attempts = attempts + 1
          return fail_result(LOCKED_STDERR)
        end
      end
      return ok_result()
    end, function()
      fixture.git(fixture.tmpdir, {"status"})
    end)
  assert(not ok, "a non-worktree-add failure must not be retried")
  assert(tostring(err):find("locked", 1, true) ~= nil, tostring(err))
  assert(attempts == 1, "expected exactly one attempt, got " .. attempts .. " attempts")
end
