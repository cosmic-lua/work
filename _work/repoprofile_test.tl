#!/usr/bin/env cosmic
-- Advertisements are inert local bytes, not permission to execute a build.
local check = require("cosmic.check")
local child = require("cosmic.child")
local env = require("cosmic.env")
local fs = require("cosmic.fs")
local repoprofile = require("_work.repoprofile")

local record FileMethods
  read: function(self: FILE, size: integer): string
  close: function(self: FILE): boolean, string, integer
end

local function directory(): string
  return check.must(fs.temp_dir(fs.join(os.getenv("TEST_TMPDIR") or "/tmp",
        "repoprofile-XXXXXX")))
end

local function write(root: string, name: string, content: string)
  assert(fs.write(fs.join(root, name), content))
end

local function run(root: string, argv: {string})
  local result = check.must(child.run(argv, {cwd = root}))
  assert(result.ok, result.stderr)
end

local function with_environment(values: {string: string}, f: function())
  local previous: {string: string} = {}
  for name in pairs(values) do previous[name] = os.getenv(name) end
  local ok, err = pcall(function()
      for name, value in pairs(values) do assert(env.set(name, value)) end
      f()
    end)
  for name in pairs(values) do
    if previous[name] == nil then assert(env.unset(name))
    else assert(env.set(name, previous[name])) end
  end
  if not ok then error(err, 0) end
end

local function with_git_config(f: function())
  local root = directory()
  write(root, "gitconfig", "")
  with_environment({GIT_CONFIG_GLOBAL = fs.join(root, "gitconfig"),
      GIT_CONFIG_NOSYSTEM = "1"}, f)
end

local function equal(got: {string}, expected: {string})
  assert(#got == #expected, "argv length differs")
  for i, word in ipairs(expected) do assert(got[i] == word, "argv differs at " .. i) end
end

-- Every resolver call, including hostile and failed inputs, is monitored.
local function resolve(root: string): repoprofile.Profile
  local original = child.run
  local calls = 0
  child.run = function(_argv: {string}, _opts?: child.Options): child.Result | nil, string
    calls = calls + 1
    return nil, "discovery subprocess sentinel"
  end
  local ok, result = pcall(repoprofile.resolve, root)
  child.run = original
  assert(calls == 0, "resolve must make ZERO subprocess calls")
  assert(ok, tostring(result))
  return result
end

local function make_root(content: string): string
  local root = directory()
  write(root, "Makefile", content)
  return root
end

local function absent(root: string)
  local p = resolve(root)
  assert(p.kind == "absent")
  assert(#p.bootstrap == 0 and #p.gate == 0)
  equal(p.check_file("unused"), {})
  equal(p.test_file("unused"), {})
end

local function test_cosmic_precedence_exact_commands_and_inert_executable()
  local root = make_root(".PHONY: gate\n")
  assert(fs.make_dirs(fs.join(root, "bin")))
  write(root, "bin/cosmic", "#!/bin/sh\nprintf executed > cosmic-marker\n")
  run(root, {"chmod", "+x", "bin/cosmic"})
  local p = resolve(root)
  assert(p.kind == "cosmic" and #p.bootstrap == 2)
  equal(p.bootstrap[1], {"bin/cosmic", "--make", "fetch"})
  equal(p.bootstrap[2], {"bin/cosmic", "--make", "build"})
  equal(p.gate, {"bin/cosmic", "--make", "ci"})
  equal(p.check_file("a.tl"), {"bin/cosmic", "--check", "types", "a.tl"})
  equal(p.test_file("a.tl"), {"bin/cosmic", "--make", "test", "a.tl"})
  assert(not fs.is_file(fs.join(root, "cosmic-marker")))
  run(root, {"chmod", "-x", "bin/cosmic"})
  write(root, "bin/cosmic", "not an executable")
  assert(resolve(root).kind == "cosmic", "presence, not executable validation")
end

local function test_make_capabilities_are_literal_and_tail_is_inert()
  local root = make_root(".PHONY: bootstrap gate check-file test-file\n"
    .. "PARSE := $(shell printf executed > parse-marker)\n"
    .. "gate:\n\t+printf executed > recipe-marker\n")
  write(root, "GNUmakefile", "$(error competing file must not be read)\n")
  local p = resolve(root)
  assert(p.kind == "make" and #p.bootstrap == 1)
  equal(p.bootstrap[1], {"make", "-f", "Makefile", "bootstrap"})
  equal(p.gate, {"make", "-f", "Makefile", "gate"})
  equal(p.check_file("x.tl"), {"make", "-f", "Makefile", "check-file", "FILE=x.tl"})
  equal(p.test_file("x.tl"), {"make", "-f", "Makefile", "test-file", "FILE=x.tl"})
  assert(not fs.is_file(fs.join(root, "parse-marker")))
  assert(not fs.is_file(fs.join(root, "recipe-marker")))
end

local function test_every_nonempty_capability_subset()
  local names = {"bootstrap", "gate", "check-file", "test-file"}
  for mask = 1, 15 do
    local chosen: {string} = {}
    local wanted: {boolean} = {}
    for i, name in ipairs(names) do
      wanted[i] = math.floor(mask / 2 ^ (i - 1)) % 2 == 1
      if wanted[i] then chosen[#chosen + 1] = name end
    end
    local p = resolve(make_root(".PHONY: " .. table.concat(chosen, "\t") .. " \t\n"))
    assert(p.kind == "make")
    assert((#p.bootstrap == 1) == wanted[1])
    assert((#p.gate > 0) == wanted[2])
    assert((#p.check_file("") > 0) == wanted[3])
    assert((#p.test_file("") > 0) == wanted[4])
  end
end

local function test_first_meaningful_line_and_all_lexical_refusals()
  local bad = {
    ".PHONY:", ".PHONY: \t", ".PHONY:gate", " .PHONY: gate", "\t.PHONY: gate",
    ".PHONY: gate gate", ".PHONY: gate unknown", ".PHONY: gate #comment",
    ".PHONY: $(TARGET)", ".PHONY: ${TARGET}", ".PHONY: gate\\",
    ".PHONY: gate; echo nope", ".PHONY: gate: dep", ".PHONY: gate|dep",
    ".PHONY: gate\\ test-file", ".PHONY:: gate", ".PHONY: gate\vtest-file",
    ".PHONY: gate\f", "\239\187\191.PHONY: gate",
    "ifeq (1,1)", "define targets", "target:", "include targets.mk",
    "VALUE := yes", "export NAME=value", "# comment\\", " \t# comment\\ \t",
    "# NUL\0comment", ".PHONY: gate\0", ".PHONY: gate\r\r",
  }
  for _, line in ipairs(bad) do
    local root = make_root(line .. "\n.PHONY: bootstrap gate check-file test-file\n")
    write(root, "targets.mk", ".PHONY: gate\n")
    absent(root)
  end
  absent(make_root("# comment\\"))
  absent(make_root(".PHONY: gate\r"))
end

local function test_line_endings_comments_and_opaque_tail()
  for _, ending in ipairs({"\n", "\r\n", ""}) do
    local p = resolve(make_root(" \t\n\t# UTF-8 café\r\n.PHONY:\tgate" .. ending))
    assert(p.kind == "make")
    equal(p.gate, {"make", "-f", "Makefile", "gate"})
  end
  assert(resolve(make_root(".PHONY: gate\n\0anything\\\n"
        .. ("x"):rep(70000))).kind == "make")
  absent(make_root(""))
  absent(make_root(" \t\r\n# comment\n "))
end

local function test_exact_prefix_limit_and_incomplete_lines()
  local declaration = ".PHONY: gate"
  for _, ending in ipairs({"", "\n", "\r\n"}) do
    local valid = (" "):rep(65536 - #declaration - #ending - 1)
    .. "\n" .. declaration .. ending
    assert(#valid == 65536)
    assert(resolve(make_root(valid)).kind == "make", "declaration at limit must fit")
    absent(make_root(" " .. valid))
  end
  local at_limit = (" "):rep(65536 - #declaration - 2) .. "\n" .. declaration .. "\n"
  assert(resolve(make_root(at_limit .. ("x"):rep(100000))).kind == "make")
  absent(make_root((" "):rep(65537)))
  absent(make_root("#" .. ("x"):rep(65536) .. "\n.PHONY: gate\n"))
end

local function test_unknown_roots_and_regular_symlink_markers()
  absent("")
  absent(fs.join(directory(), "missing"))
  local file_root = directory()
  write(file_root, "plain", ".PHONY: gate\n")
  absent(fs.join(file_root, "plain"))
  absent(file_root)
  local nested = fs.join(file_root, "nested")
  assert(fs.make_dirs(nested))
  write(file_root, "Makefile", ".PHONY: gate\n")
  absent(nested)
  local root = directory()
  write(root, "target", ".PHONY: gate\n")
  assert(fs.symlink("target", fs.join(root, "Makefile")))
  assert(resolve(root).kind == "make")
  assert(fs.make_dirs(fs.join(root, "bin")))
  assert(fs.symlink("../target", fs.join(root, "bin/cosmic")))
  assert(resolve(root).kind == "cosmic")
end

local function test_dangling_and_nonregular_markers_are_not_opened()
  for _, marker in ipairs({"Makefile", "bin/cosmic"}) do
    for _, kind in ipairs({"dangling", "directory", "fifo", "device"}) do
      local root = directory()
      assert(fs.make_dirs(fs.join(root, "bin")))
      local path = fs.join(root, marker)
      if kind == "dangling" then assert(fs.symlink("missing", path))
      elseif kind == "directory" then assert(fs.make_dirs(path))
      elseif kind == "fifo" then run(root, {"mkfifo", path})
      else assert(fs.symlink("/dev/null", path)) end
      absent(root)
    end
  end
end

local function test_file_arguments_and_arrays_are_independent()
  for _, cosmic in ipairs({false, true}) do
    local root = make_root(".PHONY: bootstrap gate check-file test-file\n")
    if cosmic then
      assert(fs.make_dirs(fs.join(root, "bin")))
      write(root, "bin/cosmic", "")
    end
    local p, q = resolve(root), resolve(root)
    p.bootstrap[1][1], p.gate[1] = "mutated", "mutated"
    assert(q.bootstrap[1][1] ~= "mutated" and q.gate[1] ~= "mutated")
    for _, file in ipairs({"", "a b=\\c; $(touch never) `echo nope`", "é.tl"}) do
      local checked, tested = p.check_file(file), p.test_file(file)
      assert(#checked == (cosmic and 4 or 5))
      assert(checked[#checked] == (cosmic and file or "FILE=" .. file))
      assert(tested[#tested] == (cosmic and file or "FILE=" .. file))
      checked[1], tested[1] = "changed", "changed"
      assert(p.check_file(file)[1] ~= "changed" and p.test_file(file)[1] ~= "changed")
    end
    assert(not fs.is_file(fs.join(root, "never")))
  end
  local p, q = resolve(directory()), resolve(directory())
  p.gate[1], p.bootstrap[1] = "changed", {"changed"}
  assert(#q.gate == 0 and #q.bootstrap == 0)
  local empty = p.check_file("")
  empty[1] = "changed"
  assert(#p.check_file("") == 0)
end

local function test_makefile_open_failure_degrades()
  local root = make_root(".PHONY: gate\n")
  local original = io.open
  io.open = function(_name: string, _mode?: string): FILE, string, integer
    return nil, "injected open failure", 0
  end
  local ok, err = pcall(absent, root)
  io.open = original
  assert(ok, tostring(err))
end

local function test_bounded_read_and_close_on_all_outcomes()
  local root = make_root(".PHONY: gate\n")
  for _, failure in ipairs({"none", "read", "read-throw", "close", "close-throw"}) do
    local file = check.must((io.open(fs.join(root, "Makefile"), "rb")))
    local methods = getmetatable(file).__index as FileMethods -- cast: stdio's untyped metatable; numeric reads only in this fixture
    local open, read, close = io.open, methods.read, methods.close
    local reads, closes = 0, 0
    io.open = function(_name: string, mode?: string): FILE, string, integer
      assert(mode == "rb")
      return file, "", 0
    end
    methods.read = function(self: FILE, size: integer): string
      reads = reads + 1
      assert(size == 65537, "discovery must perform one bounded prefix read")
      if failure == "read" then return nil end
      if failure == "read-throw" then error("injected read exception") end
      local value = read(self, size)
      if value is string then return value end
      return nil
    end
    methods.close = function(self: FILE): boolean, string, integer
      closes = closes + 1
      local result = close(self)
      if failure == "close" then return nil, "injected close failure", 0 end
      if failure == "close-throw" then error("injected close exception") end
      return result, "", 0
    end
    local ok, p = pcall(resolve, root)
    io.open, methods.read, methods.close = open, read, close
    pcall(close, file)
    assert(ok, tostring(p))
    local expected: repoprofile.Kind = failure == "none" and "make" or "absent"
    assert(p.kind == expected)
    assert(reads == 1 and closes == 1, "every read outcome must close its handle")
  end
end

local function default_base_fixtures()
  local kinds: {repoprofile.Kind} = {"absent", "make", "cosmic"}
  for _, kind in ipairs(kinds) do
    local root = directory()
    if kind == "make" then write(root, "Makefile", ".PHONY: gate\n") end
    if kind == "cosmic" then
      assert(fs.make_dirs(fs.join(root, "bin")))
      write(root, "bin/cosmic", "")
    end
    run(root, {"git", "init", "-q"})
    assert(resolve(root).kind == kind)
    assert(repoprofile.default_base(root) == "")
    run(root, {"git", "symbolic-ref", "refs/remotes/origin/HEAD",
        "refs/remotes/origin/feature/integration"})
    assert(repoprofile.default_base(root) == "feature/integration")
  end
  -- TEST_TMPDIR can live below this checkout; stop Git discovering its parent.
  local root = directory()
  local ceiling = os.getenv("GIT_CEILING_DIRECTORIES")
  assert(env.set("GIT_CEILING_DIRECTORIES", check.must(root:match("^(.*)/[^/]+$"))))
  local ok, err = pcall(function() assert(repoprofile.default_base(root) == "") end)
  if ceiling == nil then assert(env.unset("GIT_CEILING_DIRECTORIES"))
  else assert(env.set("GIT_CEILING_DIRECTORIES", ceiling)) end
  assert(ok, tostring(err))
end

local function test_default_base_is_a_local_independent_git_read()
  with_git_config(default_base_fixtures)
end

local function test_git_fixture_config_isolation_restores_even_after_failure()
  local root = directory()
  write(root, "host-config", "deliberately invalid Git configuration\n")
  local hostile = fs.join(root, "host-config")
  with_environment({GIT_CONFIG_GLOBAL = hostile, GIT_CONFIG_SYSTEM = hostile,
      GIT_CONFIG_NOSYSTEM = "0"}, function()
      local failed = check.must(child.run({"git", "init", "-q"}, {cwd = root}))
      assert(not failed.ok, "the inherited fixture config must genuinely fail Git")
      with_git_config(function()
          run(root, {"git", "init", "-q"})
          assert(repoprofile.default_base(root) == "")
        end)
      local ok, err = pcall(with_git_config, function() error("fixture sentinel") end)
      assert(not ok and tostring(err):find("fixture sentinel", 1, true))
      assert(os.getenv("GIT_CONFIG_GLOBAL") == hostile)
      assert(os.getenv("GIT_CONFIG_SYSTEM") == hostile)
      assert(os.getenv("GIT_CONFIG_NOSYSTEM") == "0")
    end)
end

local function test_default_base_exact_argv_and_failure_grammar()
  local original = child.run
  local calls = 0
  local output, success, spawn = "", true, true
  child.run = function(argv: {string}, opts?: child.Options): child.Result | nil, string
    calls = calls + 1
    equal(argv, {"git", "symbolic-ref", "-q", "refs/remotes/origin/HEAD"})
    assert(opts ~= nil and opts.cwd == "selected-checkout")
    if not spawn then return nil, "injected spawn failure" end
    return {ok = success, code = success and 0 or 1, signal = 0,
      stdout = output, stderr = ""}, ""
  end
  local ok, err = pcall(function()
      assert(repoprofile.default_base("") == "" and calls == 0)
      spawn = false
      assert(repoprofile.default_base("selected-checkout") == "")
      spawn, success = true, false
      assert(repoprofile.default_base("selected-checkout") == "")
      success = true
      for _, bad in ipairs({"", "main", "refs/remotes/upstream/main",
          "refs/remotes/origin/", " refs/remotes/origin/main",
          "refs/remotes/origin/main\n\n", "refs/remotes/origin/a\rb",
          "refs/remotes/origin/a b", "refs/remotes/origin/a\tb",
          "refs/remotes/origin/a\0b", "refs/remotes/origin/a\127b"}) do
        output = bad
        assert(repoprofile.default_base("selected-checkout") == "", "accepted malformed ref")
      end
      for _, ending in ipairs({"", "\n", "\r\n"}) do
        output = "refs/remotes/origin/feature/café" .. ending
        assert(repoprofile.default_base("selected-checkout") == "feature/café")
      end
    end)
  child.run = original
  assert(ok, tostring(err))
end
