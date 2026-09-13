#!/usr/bin/env cosmic
--- Read-only audit: preserve an actual board's refs, Git DAG, and raw logs.
--- Usage: bin/cosmic experiments/single-head/verify_snapshot.tl SOURCE [TRANSACTION]
--- All envelope construction and restoration happens in temporary repositories.
local check = require("cosmic.check")
local fs = require("cosmic.fs")
local time = require("cosmic.time")
local objects = require("_work.singlehead_objects")
local git = require("_work.singlehead_git")
local plans = require("_work.singlehead_plan")

local function closure(root: string, refs: {string: string}): {string}
  local roots: {string} = {}
  for _, sha in pairs(refs) do roots[#roots + 1] = sha end
  table.sort(roots)
  local raw = check.must(git.run(root,
      {"rev-list", "--objects", "--no-object-names", "--stdin"},
      table.concat(roots, "\n") .. "\n"))
  local out: {string} = {}
  for line in raw:gmatch("([^\n]+)") do out[#out + 1] = line end
  table.sort(out)
  return out
end

local function run(source: string, transaction: string, temporary: string): {string: any}
  local prefix = "refs/remotes/origin/"
  local original = check.must(objects.snapshot(source, prefix))
  local names: {string} = {}
  for ref in pairs(original) do names[#names + 1] = ref end
  table.sort(names)
  assert(#names > 0, "source has no canonical board refs")
  local envelope = fs.join(temporary, "envelope")
  assert(fs.make_dirs(envelope))
  check.must(git.run(envelope, {"init", "--quiet", "--object-format=sha1"}))
  local empty_tree = check.must(objects.make_tree(envelope, {}))
  local seed = check.must(objects.make_commit(envelope, empty_tree, "local audit seed"))
  local plan = check.must(plans.build_seed(source, envelope, seed, prefix,
      "cosmic-lua/work", "single-head-local-audit"))
  local head = check.must(plans.local_candidate(envelope, plan))
  local restored = fs.join(temporary, "restored")
  local state = check.must(objects.restore(envelope, head, restored))
  assert(check.must(objects.canonical(state.refs)) == check.must(objects.canonical(original)),
    "restored ref map differs")
  local before = closure(source, original)
  assert(table.concat(before, "\n") == table.concat(closure(restored, state.refs), "\n"),
    "restored object graph differs")
  local checked = 0
  for _, ref in ipairs(names) do
    if ref:match("^refs/heads/items/") and checked < 5 then
      local sha = original[ref]
      assert(check.must(git.run(source, {"log", "--format=raw", sha}))
        == check.must(git.run(restored, {"log", "--format=raw", sha})),
        "raw item log differs")
      checked = checked + 1
    end
  end
  local summary = check.must(plans.summary(plan))
  local result: {string: any} = {refs = #names, objects = #before,
    exact_logs_checked = checked, bootstrap = summary}
  if transaction ~= "" then
    local delta = check.must(plans.build_transaction(source, envelope, head,
        transaction, "cosmic-lua/work", "single-head-local-audit"))
    local final = check.must(plans.local_candidate(envelope, delta))
    local after = fs.join(temporary, "with-transaction")
    local after_state = check.must(objects.restore(envelope, final, after))
    assert(table.concat(closure(source, after_state.refs), "\n")
      == table.concat(closure(after, after_state.refs), "\n"),
      "transaction object graph differs")
    result.transaction = check.must(plans.summary(delta))
    result.transaction_status = "round-trip passed"
  end
  assert(check.must(objects.canonical(original))
    == check.must(objects.canonical(check.must(objects.snapshot(source, prefix)))),
    "source changed during the audit")
  result.source_unchanged = true
  return result
end

local function main(...: string): integer
  local args = {...}
  local source = fs.absolute_path(args[1] or ".")
  local temporary = check.must(fs.temp_dir(fs.join(os.getenv("TEST_TMPDIR") or "/tmp",
        "gitboard-native-audit-XXXXXX")))
  local started = time.monotonic_ms()
  local ok, result = pcall(run, source, args[2] or "", temporary)
  assert(fs.remove_all(temporary))
  if not ok then error(result, 0) end
  result.seconds = (time.monotonic_ms() - started) / 1000
  print(check.must(objects.canonical(result)))
  return 0
end

os.exit(main(...))
