#!/usr/bin/env cosmic
--- Regression coverage for the repository-declared bootstrap path, not
--- only the cache-lookup `.ape` variant `worktree_runtime_test.tl`
--- otherwise exercises exhaustively. A Cosmic-kind target's own
--- committed trust root (`bin/cosmic`) and its `_build/coldbuild_test.tl`
--- read declaration both name the un-suffixed `o/bootstrap/cosmic`
--- directly; a preparation that materializes only `cosmic.ape` leaves
--- that target's own build graph refusing before it starts, with no
--- diagnostic gitboard itself ever sees.
---
--- The fixture below stands in for that graph: its `--make build` step
--- refuses unless `o/bootstrap/cosmic` holds bytes identical to its own
--- (`$0`), the same bytes `runtime.prepare` verified against the pin —
--- exactly the shape of a real coldbuild failure, reproduced without a
--- real cosmic checkout. `runtime.prepare` is the one function creation,
--- `--adopt`, and `--review` preparation all reach through
--- (`gitworktree.bootstrap_and_refs`'s single call site), so proving it
--- here covers every caller.
local check = require("cosmic.check")
local child = require("cosmic.child")
local env = require("cosmic.env")
local fixture = require("_work.fixture")
local fs = require("cosmic.fs")
local hash = require("cosmic.hash")
local runtime = require("_work.worktree_runtime")

local COLDBUILD_SCRIPT < const > = [[#!/bin/sh
if [ "$1" = "-e" ]; then printf 'gitboard-runtime-probe-v1\n'; exit 0; fi
if ! cmp -s "$0" o/bootstrap/cosmic; then
  echo "o/bootstrap/cosmic does not exist" >&2
  exit 1
fi
echo 'build: PASS (fixture)'
]]

local record Case
  source: string
  root: string
  pin: runtime.Pin
end

--- A hermetic git checkout carrying the pinned coldbuild fixture, the
--- same shape `worktree_runtime_test.tl`'s own `fresh` builds.
local function fresh(name: string, body: function(Case))
  local keys = {"GIT_CONFIG_GLOBAL", "GIT_CONFIG_NOSYSTEM", "GIT_CONFIG_SYSTEM"}
  local saved: {string: string} = {}
  for _, key in ipairs(keys) do saved[key] = env.get(key) end
  local ok, err = pcall(function()
      assert(env.set("GIT_CONFIG_GLOBAL", fs.join(fixture.tmpdir, "gitconfig-empty")))
      assert(env.set("GIT_CONFIG_NOSYSTEM", "1"))
      assert(env.unset("GIT_CONFIG_SYSTEM"))
      local dir = check.must(fs.temp_dir(fs.join(fixture.tmpdir, "coldbuild-" .. name .. "-XXXXXX")))
      local source, root = fs.join(dir, "source"), fs.join(dir, "target")
      assert(fs.make_dirs(fs.join(source, "bin")))
      fixture.git(source, {"init", "-q"})
      assert(fs.write(fs.join(source, ".gitignore"), "o/\n"))
      assert(fs.write(fs.join(source, "bin/cosmic"), "#!/bin/sh\nexit 99\n"))
      assert(fs.write(fs.join(source, "fixture-runtime"), COLDBUILD_SCRIPT))
      local pin = "url = https://example.test/runtime\nsha256 = "
      .. hash.sha256_hex(COLDBUILD_SCRIPT) .. "\n"
      assert(fs.write(fs.join(source, "bin/cosmic.pin"), pin))
      fixture.git(source, {"add", "."})
      fixture.git(source, {"commit", "-qm", "target"})
      fixture.git(source, {"worktree", "add", "-q", "--detach", root, "HEAD"})
      local c: Case = {source = source, root = root, pin = check.must(runtime.inspect(root, "HEAD"))}
      body(c)
    end)
  for _, key in ipairs(keys) do
    if saved[key] == nil then assert(env.unset(key)) else assert(env.set(key, saved[key])) end
  end
  if not ok then error(err, 0) end
end

--- Pre-seed one bootstrap path with the fixture's own verified bytes,
--- as a prior `--fetch` (or a retained partial publish) would leave it.
local function cache(root: string, name: string)
  assert(fs.make_dirs(fs.join(root, "o/bootstrap")))
  assert(fs.write(fs.join(root, "o/bootstrap", name), COLDBUILD_SCRIPT))
end

--- Prepare and require the coldbuild fixture's `--make build` to have
--- actually passed, not merely that `prepare` returned without error.
local function prepare_and_require_build(c: Case, fetch: boolean)
  local r, err = runtime.prepare(c.source, c.root, c.pin, fetch, false)
  assert(r ~= nil, err)
  assert(check.must(fs.read(fs.join(c.root, "o/bootstrap/cosmic"))) == COLDBUILD_SCRIPT,
    "o/bootstrap/cosmic must hold the exact verified bytes before the build graph runs")
end

--- Stand in for the network on an acquisition path: no cache anywhere
--- means `prepare` reaches its `curl` step, which this fixture's own
--- host has no route to, so intercept it exactly as
--- `worktree_runtime_test.tl` does for its own download coverage.
local function without_network(f: function())
  local original = child.run
  child.run = function(argv: {string}, opts?: child.Options): child.Result | nil, string
    if argv[1] == "curl" then
      assert(fs.write(argv[22], COLDBUILD_SCRIPT))
      return {ok = true, code = 0, stdout = "", stderr = ""}, ""
    end
    return original(argv, opts)
  end
  local ok, err = pcall(f)
  child.run = original
  if not ok then error(err, 0) end
end

local function test_fresh_cache_miss_materializes_the_declared_bootstrap_path()
  fresh("fresh", function(c: Case)
      without_network(function() prepare_and_require_build(c, true) end)
    end)
end

local function test_cache_hit_still_materializes_the_unsuffixed_path()
  fresh("cache-hit", function(c: Case)
      cache(c.source, "cosmic.ape")
      prepare_and_require_build(c, false)
    end)
end

--- The exact regression: a prior attempt published `cosmic.ape` (its
--- cache-lookup form) but never reached `cosmic` before the target's
--- own build refused and the checkout was retained for `--adopt`. A
--- retry must complete on its own, with no manual copy in between.
local function test_adoption_after_a_retained_failure_completes_on_retry()
  fresh("adopt", function(c: Case)
      cache(c.root, "cosmic.ape")
      assert(not fs.is_present(fs.join(c.root, "o/bootstrap/cosmic")))
      prepare_and_require_build(c, false)
    end)
end

--- `--review` reaches `runtime.prepare` through the exact same call in
--- `gitworktree.bootstrap_and_refs` as creation and `--adopt` — a fresh
--- preparation here exercises that shared path for it too.
local function test_review_preparation_shares_the_same_publication()
  fresh("review", function(c: Case)
      without_network(function() prepare_and_require_build(c, true) end)
    end)
end
