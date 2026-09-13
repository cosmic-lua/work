#!/usr/bin/env cosmic
local child = require("cosmic.child")
local fs = require("cosmic.fs")
local testfixture = require("_work.fixture")
local binding = require("_work.singlehead_binding")

local root = fs.join(testfixture.tmpdir, "singlehead-binding")
assert(fs.make_dirs(root))
local function git(...: string)
  local r = assert(child.run({"git", ...}, {cwd = root}))
  assert(r.ok, r.stderr)
end
git("init", "-q")
git("remote", "add", "origin", "https://github.com/acme/board.git")

local function test_matching_fetch_and_push_identity()
  git("remote", "set-url", "--push", "origin",
    "git@github.com:acme/board.git")
  local got, err = binding.inspect(root, "origin", "acme/board", "envelope")
  assert(got ~= nil, err)
  assert(got.fetch_url == "https://github.com/acme/board.git")
  assert(got.push_url == "git@github.com:acme/board.git")
end
test_matching_fetch_and_push_identity()

local function test_split_repository_identity_refuses()
  git("remote", "set-url", "origin", "https://github.com/acme/other.git")
  local got, err = binding.inspect(root, "origin", "acme/board", "envelope")
  assert(got == nil and err:find("fetch remote targets acme/other", 1, true), err)
  git("remote", "set-url", "origin", "https://github.com/acme/board.git")
  git("remote", "set-url", "--push", "origin",
    "https://github.com/acme/other.git")
  got, err = binding.inspect(root, "origin", "acme/board", "envelope")
  assert(got == nil and err:find("push remote targets acme/other", 1, true), err)
end
test_split_repository_identity_refuses()

local function test_multiple_or_unsafe_urls_refuse()
  git("remote", "set-url", "--push", "--delete", "origin", ".*")
  git("remote", "set-url", "--add", "--push", "origin",
    "https://github.com/acme/board.git")
  git("remote", "set-url", "--add", "--push", "origin",
    "https://github.com/acme/other.git")
  local got, err = binding.inspect(root, "origin", "acme/board", "envelope")
  assert(got == nil and err:find("exactly one push URL", 1, true), err)
  got, err = binding.inspect(root, "-v", "acme/board", "envelope")
  assert(got == nil and err:find("not safe", 1, true), err)
end
test_multiple_or_unsafe_urls_refuse()

local function test_reserved_envelope_branches_refuse()
  git("remote", "set-url", "--delete", "--push", "origin",
    "https://github.com/acme/other.git")
  for _, branch in ipairs({"items", "ended", "board", "claims",
      "claim-batches", "items/nested"}) do
    local got, err = binding.inspect(root, "origin", "acme/board", branch)
    assert(got == nil and err:find("board namespace", 1, true),
      branch .. ": " .. err)
  end
end
test_reserved_envelope_branches_refuse()
print("singlehead_binding_test: ok")
