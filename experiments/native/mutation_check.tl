#!/usr/bin/env cosmic
--- Native semantic mutations in an isolated HEAD plus explicit source overlays.
--- Run with the actual runtime and this path, then CATALOG and optional OVERLAY paths.
local child = require("cosmic.child")
local check = require("cosmic.check")
local fs = require("cosmic.fs")
local env = require("cosmic.env")
local literal = require("cosmic.literal")
local proc = require("cosmic.proc")
local rand = require("cosmic.rand")

local record Mutation
  file: string
  before: string
  after: string
  test: string
  filter: string | nil
end
local record Result
  outcome: string
  evidence: string
end

local function run(argv: {string}, cwd: string, filter?: string): child.Result
  local result, err = child.run(argv, {cwd = cwd,
      env = env.list({set = {COSMIC_TEST_FILTER = filter or ""}})})
  assert(result ~= nil, err)
  return result
end

local function command(runtime: string, root: string, verb: string,
    paths: {string}, filter?: string): child.Result
  local argv = {runtime, "--make", verb}
  for _, path in ipairs(paths) do argv[#argv + 1] = path end
  return run(argv, root, filter)
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
    assert(file:match("^_work/[a-z0-9_]+%.tl$") and test:match("^_work/[a-z0-9_]+_test%.tl$"),
      "mutation paths must name native single-file modules and tests")
    assert(before ~= "" and before ~= after, "mutation must change nonempty source")
    local filter: string | nil
    local raw_filter = value.filter
    if raw_filter ~= nil then
      assert(raw_filter is string, "mutation filter must be a string")
      filter = raw_filter
      assert(filter:match("^test_[a-z0-9_]+$"), "mutation filter must name an exact test function")
    end
    cases[id] = {file = file, before = before, after = after, test = test, filter = filter}
  end
  assert(next(cases) ~= nil, "empty mutation catalog")
  return cases
end

local function replace_once(source: string, before: string, after: string): string | nil, string
  local first, last = source:find(before, 1, true)
  if first == nil then return nil, "mutation source no longer matches" end
  if source:find(before, last + 1, true) ~= nil then return nil, "mutation source is ambiguous" end
  return source:sub(1, first - 1) .. after .. source:sub(last + 1)
end

local function test_records(root: string, test: string): string
  return fs.read(fs.join(root, "o", test .. ".test.tests")) or ""
end

local function selected(records: string, filter: string | nil): boolean
  local count = 0
  for line in records:gmatch("[^\n]+") do
    local name = line:match("^(%S+)")
    if name == nil then return false end
    if filter == nil or name:find(filter, 1, true) ~= nil then
      if filter ~= nil and name ~= filter then return false end
      count = count + 1
    end
  end
  return count > 0 and (filter == nil or count == 1)
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
    label: string, test: string, filter?: string): child.Result, string
  local lua, modules = generated_paths(test)
  assert(fs.is_present(fs.join(root, lua)), "test discovery did not generate Lua: " .. test)
  assert(fs.is_present(fs.join(root, modules)), "test discovery did not generate modules: " .. test)
  local prefix = fs.join(output, label .. "-" .. rand.token())
  local executed = run({runtime, "--test", prefix, runtime,
      "--modules", modules, lua}, root, filter)
  local evidence = executed.stdout .. executed.stderr
  .. (fs.read(prefix .. ".out") or "") .. (fs.read(prefix .. ".err") or "")
  assert(fs.write(fs.join(output, label .. "-fresh.log"), evidence))
  local count = tonumber(evidence:match("(%d+) checks:")) or 0
  assert(count > 0 and (filter == nil or count == 1), "fresh test selection is empty or ambiguous")
  return executed, evidence
end

local function control(runtime: string, root: string, output: string,
    label: string, test: string, filter?: string)
  clear_results(root, {test})
  local discovered = command(runtime, root, "test", {test}, filter)
  assert(fs.write(fs.join(output, label .. "-discovery.log"),
      discovered.stdout .. discovered.stderr))
  local records = test_records(root, test)
  assert(selected(records, filter), "test discovery selection is empty or ambiguous: " .. test)
  assert(discovered.ok, label .. " discovery run failed: " .. test)
  local executed = fresh_test(runtime, root, output, label, test, filter)
  assert(executed.ok, label .. " fresh execution failed: " .. test)
end

local function experiment(runtime: string, root: string, output: string,
    id: string, mutation: Mutation): Result
  local path = fs.join(root, mutation.file)
  local original = assert(fs.read(path))
  local changed, match_err = replace_once(original, mutation.before, mutation.after)
  if changed == nil then return {outcome = "invalid", evidence = match_err} end
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
  local discovered = command(runtime, root, "test", {mutation.test}, mutation.filter)
  local records = test_records(root, mutation.test)
  assert(fs.write(fs.join(output, id .. "-discovery.log"),
      discovered.stdout .. discovered.stderr))
  assert(fs.write(fs.join(output, id .. "-tests.txt"), records))
  local lua, modules = generated_paths(mutation.test)
  if not selected(records, mutation.filter) or not fs.is_present(fs.join(root, lua))
  or not fs.is_present(fs.join(root, modules)) then
    assert(fs.write(path, original))
    return {outcome = "invalid", evidence = "mutant failed test compilation or discovery"}
  end
  local executed, failure = fresh_test(runtime, root, output, id, mutation.test, mutation.filter)
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
  local ids, paths = {}, {}
  local selections: {string: Mutation} = {}
  for id, case in pairs(cases) do
    ids[#ids + 1] = id
    local key = case.test .. ":" .. (case.filter or "")
    if selections[key] == nil then paths[#paths + 1], selections[key] = key, case end
  end
  table.sort(ids)
  table.sort(paths)
  for _, key in ipairs(paths) do
    local case = selections[key]
    local name = key:gsub("[^A-Za-z0-9]+", "-")
    control(runtime, root, output, "baseline-" .. name, case.test, case.filter)
  end
  local results: {string: Result} = {}
  for _, id in ipairs(ids) do
    results[id] = experiment(runtime, root, output, id, cases[id])
    print(id .. ": " .. results[id].outcome)
  end
  -- Recompile and rerun the restored source too: stale mutant artifacts must
  -- not masquerade as a clean baseline or leak into the next run.
  for _, key in ipairs(paths) do
    local case = selections[key]
    local name = key:gsub("[^A-Za-z0-9]+", "-")
    control(runtime, root, output, "restored-" .. name, case.test, case.filter)
  end
  return results
end

local function main(...: string): integer
  local args = {...}
  local source = fs.absolute_path(".")
  local runtime = check.must(proc.interpreter())
  local catalog = fs.absolute_path(args[1] or "experiments/native/mutations.tl")
  local cases = checked_catalog(catalog)
  local output = fs.join(source, "o/native-state-mutations", rand.token())
  assert(fs.make_dirs(output))
  print("Evidence: " .. output)
  local revision = run({"git", "rev-parse", "HEAD"}, source)
  assert(revision.ok, revision.stderr)
  local checkout = fs.join(output, "checkout")
  local made = run({"git", "worktree", "add", "--detach", checkout,
      (revision.stdout:gsub("%s+$", ""))}, source)
  assert(made.ok, made.stderr)
  -- Explicit overlays avoid mixing unrelated in-progress modules into HEAD.
  for index = 2, #args do
    local path = args[index]
    assert(path:match("^_work/[a-z0-9_]+%.tl$"), "unsafe source overlay")
    assert(fs.write(fs.join(checkout, path), assert(fs.read(fs.join(source, path)))))
  end
  -- The index records the precise tracked source with any requested overlays.
  -- Git object identities replace a duplicate, unbounded source-tree snapshot.
  local added = run({"git", "add", "--", "_work"}, checkout)
  assert(added.ok, added.stderr)
  local source_tree = run({"git", "write-tree"}, checkout)
  assert(source_tree.ok, source_tree.stderr)
  local catalog_sha = run({"git", "hash-object", catalog}, source)
  assert(catalog_sha.ok, catalog_sha.stderr)
  local overlays: {string: string} = {}
  for index = 2, #args do
    local sha = run({"git", "hash-object", args[index]}, source)
    assert(sha.ok, sha.stderr)
    overlays[args[index]] = sha.stdout:gsub("%s+$", "")
  end
  assert(fs.write(fs.join(output, "provenance.literal"), assert(literal.format({
            revision = revision.stdout:gsub("%s+$", ""),
            source_tree_sha = source_tree.stdout:gsub("%s+$", ""),
            catalog_blob_sha = catalog_sha.stdout:gsub("%s+$", ""),
            runtime = runtime, overlays = overlays, catalog = cases,
            arguments = table.concat(args, "\n")}))))
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
