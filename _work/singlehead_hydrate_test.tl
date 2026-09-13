#!/usr/bin/env cosmic
--- Real-Git coverage for the two ref guards that make hydration atomic and
--- monotonic: the exact envelope witness and the materialized-head ancestry.
local check = require("cosmic.check")
local child = require("cosmic.child")
local fs = require("cosmic.fs")
local hydrate = require("_work.singlehead_hydrate")
local objects = require("_work.singlehead_objects")
local refs = require("_work.refs")

local BASE < const > = assert(os.getenv("TEST_TMPDIR"))
local REPOSITORY < const > = "example/board"
local BRANCH < const > = "envelope"
local ENVELOPE_REF < const > = "refs/remotes/origin/" .. BRANCH
local PREFIX < const > = "refs/remotes/origin/"

local function init(name: string): string
  local root = fs.join(BASE, name)
  assert(fs.make_dirs(root))
  local result = check.must(child.run(
      {"git", "init", "--quiet", "--object-format=sha1"}, {cwd = root}))
  assert(result.ok, result.stderr)
  return root
end

local function archive(root: string, message: string, parent?: string): string
  local state: objects.State = {format = objects.FORMAT,
    repository = REPOSITORY, branch = BRANCH, refs = {}, packs = {}, receipts = {}}
  local tree = check.must(objects.make_tree(root, {{path = objects.STATE_PATH,
          mode = "100644", otype = "blob",
          content = check.must(objects.encode_state(state))}}))
  return check.must(objects.make_commit(root, tree, message, parent))
end

local function test_exact_envelope_ref_is_a_hydration_witness()
  local root = init("hydrate-envelope-witness")
  local selected = archive(root, "selected envelope")
  local advanced = archive(root, "advanced envelope", selected)
  assert(refs.update_ref(root, ENVELOPE_REF, selected, refs.ZERO_SHA))
  assert(refs.update_ref(root, ENVELOPE_REF, advanced, selected))
  local result, err = hydrate.hydrate(root, selected, PREFIX, ENVELOPE_REF,
    REPOSITORY, BRANCH)
  assert(result == nil and err ~= "",
    "hydration must fail when its exact envelope ref has advanced")
  assert(check.must(refs.read_ref(root, hydrate.MATERIALIZED_REF)) == refs.ZERO_SHA)
end
test_exact_envelope_ref_is_a_hydration_witness()

local function test_materialized_head_cannot_regress()
  local root = init("hydrate-materialized-monotonic")
  local first = archive(root, "first envelope")
  local second = archive(root, "second envelope", first)
  assert(refs.update_ref(root, ENVELOPE_REF, second, refs.ZERO_SHA))
  assert(hydrate.hydrate(root, second, PREFIX, ENVELOPE_REF,
      REPOSITORY, BRANCH))
  assert(refs.update_ref(root, ENVELOPE_REF, first, second))
  local result, err = hydrate.hydrate(root, first, PREFIX, ENVELOPE_REF,
    REPOSITORY, BRANCH)
  assert(result == nil and err:find("regress", 1, true), err)
  assert(check.must(refs.read_ref(root, hydrate.MATERIALIZED_REF)) == second)
end
test_materialized_head_cannot_regress()

print("singlehead_hydrate_test: ok")
