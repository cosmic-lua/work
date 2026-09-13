#!/usr/bin/env cosmic
--- Isolated semantic mutation checks for the migration proof. Run with
--- `bin/cosmic experiments/native/migration_mutations.tl RUNTIME REPOSITORY`.
--- The direct test tail is generated from current sources, so stale compiled
--- tests cannot disguise a surviving mutant. Every mutant gets its own source
--- copy; the shared checkout is never edited.
---
--- A campaign, not a test: it copies the tree once per mutant and type-checks
--- and runs each one, which is minutes of work and a deliberate call rather
--- than something every gate should pay for. It lives here beside the other
--- native campaigns instead of under `_work/`, where its load-time `os.exit`
--- would make it a module no caller could require.
local child = require("cosmic.child")
local env = require("cosmic.env")
local fs = require("cosmic.fs")
local wire = require("_work.singlehead_literal")

local record Case
  file: string
  before: string
  after: string
  test: string
  test_file: string
end
local cases: {string: Case} = {
  prose_only = {file = "migrate6_replay.tl", before = "gitreadlog.prose_of(event.message:match(\"\\n\\n(.*)$\") or \"\")",
    after = "(gitreadlog.prose_of(\"\") or \"\") .. (event.message:match(\"\\n\\n(.*)$\") or \"\")",
    test_file = "migrate6_logs_test.tl", test = "test_migration_preserves_prose_and_empty_attribution_without_fake_notes"},
  pre_snapshot_freeze = {file = "migrate6_publish.tl", before = "proof.frozen_at > cp.snapshot_at",
    after = "proof.frozen_at > cp.snapshot_at and false", test = "test_synthetic_freeze_staged_seed_and_atomic_activation"},
  observation_order = {file = "migrate6_freeze.tl", before = "after.observed_at < before.observed_at",
    after = "after.observed_at < before.observed_at and false", test_file = "migrate6_freeze_test.tl",
    test = "test_freeze_rejects_missing_access_and_changed_or_reordered_observations"},
  missing_live_state = {file = "migrate6.tl", before = "if head == \"\" then return false, \"catch-up refuses without a confirmed state head\" end",
    after = "if head == \"\" then return true, \"\" end", test = "test_catch_up_checks_live_destination_and_refuses_missing_state"},
  exact_message = {file = "migrate6_replay.tl", before = "fastimport.data_block(event.message)",
    after = "fastimport.data_block(event.message .. \"\\n\")",
    test = "test_migration_exact_history_logs_marks_and_offline_restart"},
  acquisition_root = {file = "migrate6_replay.tl", before = "id = st.root, holder = st.holder",
    after = "id = batch, holder = st.holder",
    test = "test_claim_bridge_preserves_imported_root_on_expired_renewal"},
  added_ref = {file = "migrate6_source.tl", before = "if expected[ref] == nil then",
    after = "if expected[ref] == nil and false then", test = "test_refset_integrity_and_mark_validation"},
  accumulated_log = {file = "migrate6_replay.tl", before = "logs[id][name] = blobs[entry.sha].content",
    after = "logs[id][name] = nil", test = "test_catch_up_appends_without_rewriting_marks_or_losing_logs"},
  shallow_source = {file = "migrate6_source.tl", before = "if shallow:match(\"true\") then",
    after = "if shallow:match(\"true\") and false then", test = "test_checkpoint_restart_and_missing_source_closure"},
  activation_recheck = {file = "migrate6_publish.tl", before = "if not same then return nil, drift end",
    after = "if not same and false then return nil, drift end",
    test = "test_synthetic_freeze_staged_seed_and_atomic_activation"},
  shared_history = {file = "migrate6_source.tl", before = "if not present then shared.ids[#shared.ids + 1] = id;",
    after = "if not present and false then shared.ids[#shared.ids + 1] = id;",
    test = "test_shared_source_history_replays_once_for_every_item_path"},
  interrupted_candidate = {file = "migrate6_replay.tl", before = "local attempt = ksuid.new()",
    after = "local _dropped, _drop_err = source.git(root, {\"update-ref\", \"-d\", REF})\n  local attempt = ksuid.new()",
    test = "test_restart_preserves_completed_candidate_until_success"},
}

local function main(...: string): integer
  local args = {...}
  local runtime, root = args[1], args[2]
  -- assert: a campaign invoked without its two arguments has nothing to check
  assert(runtime ~= nil and root ~= nil,
    "usage: migration_mutations.tl RUNTIME REPOSITORY")
  local scratch = assert(fs.temp_dir(fs.join(env.get("TEST_TMPDIR") or "/tmp", "migrate6-mutants-XXXXXX")))
  local results: {string: string} = {}
  local names: {string} = {}
  for name in pairs(cases) do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do
    local case = cases[name]
    local isolated = fs.join(scratch, name)
    assert(fs.make_dirs(isolated))
    assert(fs.copy_tree(fs.join(root, "_work"), fs.join(isolated, "_work")))
    local target = fs.join(isolated, "_work", case.file)
    local original = assert(fs.read(target))
    local first, last = original:find(case.before, 1, true)
    assert(first ~= nil and original:find(case.before, last + 1, true) == nil,
      "mutation must match exactly once: " .. name)
    assert(fs.write(target, original:sub(1, first - 1) .. case.after .. original:sub(last + 1)))
    local checked = assert(child.run({runtime, "--check", "types", target}, {cwd = isolated}))
    assert(checked.ok, "mutant must typecheck: " .. name .. " " .. checked.stderr)
    local temp = fs.join(isolated, "tmp")
    assert(fs.make_dirs(temp))
    local test_body = assert(fs.read(fs.join(isolated, "_work", case.test_file or "migrate6_test.tl")))
    assert(test_body:find("local function " .. case.test .. "(", 1, true), "unknown mutant test")
    local direct = fs.join(isolated, "direct_test.tl")
    assert(fs.write(direct, test_body .. "\nos.exit(require(\"cosmic.test\").main({{name=\"" ..
        case.test .. "\", fn=" .. case.test .. "}}))\n"))
    local ran = assert(child.run({runtime, direct},
        {cwd = isolated, env = env.list({set = {TEST_TMPDIR = temp, COSMIC_TEST_FILTER = case.test}})}))
    assert(not ran.ok and ran.stdout:find("1 checks: 0 passed", 1, true),
      "semantic mutant survived or failed outside its test: " .. name .. " " .. ran.stdout .. ran.stderr)
    results[name] = "killed"
    print(name .. ": killed")
  end
  local report = assert(wire.encode(results))
  assert(fs.make_dirs(fs.join(root, "o/migrate6")))
  assert(fs.write(fs.join(root, "o/migrate6/mutations.literal"), report, {atomic = true}))
  assert(fs.remove_all(scratch))
  return 0
end
os.exit(main(...)) -- exits: a campaign script is a process boundary with no caller
