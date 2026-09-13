#!/usr/bin/env cosmic
--- Targeted behavioral mutations in an isolated checkout of committed HEAD.
--- Run with bin/cosmic experiments/single-head/mutation_check.tl [CATALOG].
local child = require("cosmic.child")
local fs = require("cosmic.fs")
local literal = require("cosmic.literal")
local rand = require("cosmic.rand")

local record Mutation
  file: string
  before: string
  after: string
  test: string
end
local record Result
  outcome: string
  evidence: string
end

local function run(argv: {string}, cwd: string): child.Result
  local result, err = child.run(argv, {cwd = cwd})
  assert(result ~= nil, err)
  return result
end

local function command(runtime: string, root: string, verb: string,
    paths: {string}): child.Result
  local argv = {runtime, "--make", verb}
  for _, path in ipairs(paths) do argv[#argv + 1] = path end
  return run(argv, root)
end

local function checked_catalog(path: string): {string: Mutation}
  local parsed, err = literal.parse_file(path)
  assert(parsed ~= nil, err)
  local cases: {string: Mutation} = {}
  for id, value in pairs(parsed) do
    assert(id:match("^[a-z][a-z0-9_]+$"), "unsafe mutation name")
    assert(value is {string: any}, "mutation must be a record")
    local file, before, after, test = value.file, value.before, value.after, value.test
    assert(file is string and before is string and after is string and test is string,
      "mutation requires file/before/after/test strings")
    assert(file:match("^_work/[a-z_]+%.tl$") and test:match("^_work/[a-z_]+_test%.tl$"),
      "mutation paths must name native single-file modules and tests")
    assert(before ~= "" and before ~= after, "mutation must change nonempty source")
    cases[id] = {file = file, before = before, after = after, test = test}
  end
  assert(next(cases) ~= nil, "empty mutation catalog")
  return cases
end

local function replace_once(source: string, before: string, after: string): string
  local first, last = source:find(before, 1, true)
  assert(first ~= nil, "mutation source no longer matches")
  assert(source:find(before, last + 1, true) == nil, "mutation source is ambiguous")
  return source:sub(1, first - 1) .. after .. source:sub(last + 1)
end

local function test_records(root: string, test: string): string
  return fs.read(fs.join(root, "o", test .. ".test.tests")) or ""
end

local function clear_results(root: string, tests: {string})
  for _, test in ipairs(tests) do
    for _, suffix in ipairs({".test.got", ".test.tests", ".test.in",
        ".test.result", ".test.out", ".test.err", ".test.time",
        ".test.modules"}) do
      local path = fs.join(root, "o", test .. suffix)
      if fs.is_present(path) then assert(fs.remove(path)) end
    end
  end
end

local function generated_paths(test: string): string, string
  local lua = fs.join("o", (test:gsub("%.tl$", ".lua")))
  local modules = fs.join("o", test .. ".test.modules")
  return lua, modules
end

local function assertion_trace(output: string): boolean
  return output:find("assertion failed", 1, true) ~= nil
  or output:find("in global 'assert'", 1, true) ~= nil
  or output:find("in function 'assert'", 1, true) ~= nil
  or (output:find("/cosmic/check.lua:", 1, true) ~= nil
    and output:find("in field 'must'", 1, true) ~= nil)
end

--- Execute generated Lua through a unique native test prefix. The make step
--- discovers tests and writes the module manifest; none of its cached verdict
--- files contribute to this result.
local function fresh_test(runtime: string, root: string, output: string,
    label: string, test: string): child.Result, string
  local lua, modules = generated_paths(test)
  assert(fs.is_present(fs.join(root, lua)), "test discovery did not generate Lua: " .. test)
  assert(fs.is_present(fs.join(root, modules)), "test discovery did not generate modules: " .. test)
  local prefix = fs.join(output, label .. "-" .. rand.token())
  local executed = run({runtime, "--test", prefix, runtime,
      "--modules", modules, lua}, root)
  local evidence = executed.stdout .. executed.stderr
  .. (fs.read(prefix .. ".out") or "") .. (fs.read(prefix .. ".err") or "")
  assert(fs.write(fs.join(output, label .. "-fresh.log"), evidence))
  return executed, evidence
end

local function control(runtime: string, root: string, output: string,
    label: string, test: string)
  clear_results(root, {test})
  local discovered = command(runtime, root, "test", {test})
  assert(fs.write(fs.join(output, label .. "-discovery.log"),
      discovered.stdout .. discovered.stderr))
  local records = test_records(root, test)
  assert(records ~= "", "test discovery produced no records: " .. test)
  assert(discovered.ok, label .. " discovery run failed: " .. test)
  local executed = fresh_test(runtime, root, output, label, test)
  assert(executed.ok, label .. " fresh execution failed: " .. test)
end

local function experiment(runtime: string, root: string, output: string,
    id: string, mutation: Mutation): Result
  local path = fs.join(root, mutation.file)
  local original = assert(fs.read(path))
  local changed = replace_once(original, mutation.before, mutation.after)
  assert(fs.write(path, changed))
  local checked = run({runtime, "--check", "types", mutation.file}, root)
  assert(fs.write(fs.join(output, id .. "-compile.log"), checked.stdout .. checked.stderr))
  if not checked.ok then
    assert(fs.write(path, original))
    return {outcome = "invalid", evidence = "mutant failed strict compilation"}
  end
  -- Use the actual build/test-discovery pipeline. Directly running a .tl
  -- file skips test functions that the compiler normally registers.
  clear_results(root, {mutation.test})
  local compiled = fs.join(root, "o", (mutation.file:gsub("%.tl$", ".lua")))
  if fs.is_present(compiled) then assert(fs.remove(compiled)) end
  local discovered = command(runtime, root, "test", {mutation.test})
  local records = test_records(root, mutation.test)
  assert(fs.write(fs.join(output, id .. "-discovery.log"),
      discovered.stdout .. discovered.stderr))
  assert(fs.write(fs.join(output, id .. "-tests.txt"), records))
  local lua, modules = generated_paths(mutation.test)
  if records == "" or not fs.is_present(fs.join(root, lua))
  or not fs.is_present(fs.join(root, modules)) then
    assert(fs.write(path, original))
    return {outcome = "invalid", evidence = "mutant failed test compilation or discovery"}
  end
  local executed, failure = fresh_test(runtime, root, output, id, mutation.test)
  assert(fs.write(path, original))
  if executed.ok then
    return {outcome = "survived", evidence = "fresh generated-Lua execution accepted the mutant"}
  end
  if assertion_trace(failure) then
    return {outcome = "killed", evidence = "fresh generated-Lua assertion failed"}
  end
  return {outcome = "error", evidence = "fresh execution failed without an assertion trace"}
end

local function check_all(runtime: string, root: string, output: string,
    cases: {string: Mutation}): {string: Result}
  local ids, paths, seen = {}, {}, {}
  for id, case in pairs(cases) do
    ids[#ids + 1] = id
    if not seen[case.test] then paths[#paths + 1], seen[case.test] = case.test, true end
  end
  table.sort(ids)
  table.sort(paths)
  for _, test in ipairs(paths) do
    local name = test:gsub("[^A-Za-z0-9]+", "-")
    control(runtime, root, output, "baseline-" .. name, test)
  end
  local results: {string: Result} = {}
  for _, id in ipairs(ids) do
    results[id] = experiment(runtime, root, output, id, cases[id])
    print(id .. ": " .. results[id].outcome)
  end
  -- Recompile and rerun the restored source too: stale mutant artifacts must
  -- not masquerade as a clean baseline or leak into the next run.
  for _, test in ipairs(paths) do
    local name = test:gsub("[^A-Za-z0-9]+", "-")
    control(runtime, root, output, "restored-" .. name, test)
  end
  return results
end

local function main(...: string): integer
  local args = {...}
  local source = fs.absolute_path(".")
  local runtime = fs.join(source, "o/bootstrap/cosmic")
  assert(fs.is_present(runtime), "run via bin/cosmic so its pinned runtime is available")
  local catalog = fs.absolute_path(args[1] or "experiments/single-head/mutations.tl")
  local cases = checked_catalog(catalog)
  local output = fs.join(source, "o/single-head-mutations", rand.token())
  assert(fs.make_dirs(output))
  local checkout = fs.join(output, "checkout")
  local made = run({"git", "worktree", "add", "--detach", checkout, "HEAD"}, source)
  assert(made.ok, made.stderr)
  local ok, results = pcall(check_all, runtime, checkout, output, cases)
  local cleaned = run({"git", "worktree", "remove", "--force", checkout}, source)
  assert(cleaned.ok, cleaned.stderr)
  if not ok then error(results, 0) end
  local report = assert(literal.format(results))
  assert(fs.write(fs.join(output, "results.literal"), report))
  print("Results: " .. fs.join(output, "results.literal"))
  for _, result in pairs(results) do
    if result.outcome ~= "killed" then return 1 end
  end
  return 0
end

os.exit(main(...))
