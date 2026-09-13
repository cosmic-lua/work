#!/usr/bin/env cosmic
--- Isolated semantic mutation checks for the migration proof. Invoke with the
--- pinned runtime, repository root, and an existing compiled migration test.
--- Every mutant gets its own source copy; the shared checkout is never edited.
local child = require("cosmic.child")
local env = require("cosmic.env")
local fs = require("cosmic.fs")
local wire = require("_work.singlehead_literal")

local record Case
  file: string
  before: string
  after: string
  test: string
end
local cases: {string: Case} = {
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
}

local function main(...: string): integer
  local args = {...}
  local runtime, root = args[1], args[2]
  assert(runtime ~= nil and root ~= nil, "usage: migrate6_mutations.tl RUNTIME REPOSITORY")
  local scratch = assert(fs.temp_dir("/tmp/migrate6-mutants-XXXXXX"))
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
    local ran = assert(child.run({runtime, fs.join(root, "o/_work/migrate6_test.lua")},
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
os.exit(main(...))
