#!/usr/bin/env cosmic
-- Parse refusals belong to the shared dispatcher; successful help and
-- dash-leading titles still follow their existing paths.
local check = require("cosmic.check")
local commands = require("_work.gitcommands")
local doctrine = require("_work.doctrine")
local flags = require("cosmic.flags")
local fixture = require("_work.fixture")
local gitboard = require("_work.gitboard")
local store = require("_work.store")

local function capture(...: string): integer, string, string
  local stdout, stderr = assert(io.tmpfile()), assert(io.tmpfile())
  local old_stdout, old_stderr, old_print = io.stdout, io.stderr, _G.print
  io.stdout, io.stderr = stdout, stderr
  _G.print = function(...: any)
    local parts: {string} = {}
    for i = 1, select("#", ...) do
      parts[i] = tostring((select(i, ...)))
    end
    stdout:write(table.concat(parts, "\t") .. "\n")
  end
  local ok, code = pcall(gitboard.main, ...)
  io.stdout, io.stderr, _G.print = old_stdout, old_stderr, old_print
  stdout:seek("set")
  stderr:seek("set")
  local output, diagnostic = stdout:read("*a"), stderr:read("*a")
  stdout:close()
  stderr:close()
  if not ok then error(code, 0) end
  return code, output, diagnostic
end

local function test_parse_refusals_emit_only_the_existing_diagnostic()
  local cases: {{string}} = {
    {"new", "--bogus"}, {"take", "--bogus"},
    {"snapshot", "--summary"}, {"not-a-command"}, {},
  }
  local diagnostics: {string} = {
    "unknown option: --bogus (try --help)",
    "unknown option: --bogus (try --help)",
    "option requires a value: --summary",
  }
  for i, argv in ipairs(cases) do
    local parsed, diagnostic = flags.command(commands.CSPEC, argv)
    assert(parsed == nil, "fixture must be a parser refusal")
    if diagnostics[i] ~= nil then
      assert(diagnostic == diagnostics[i], "preserve the parser diagnostic")
    end
    local code, output, err = capture(table.unpack(argv))
    assert(code == 1, "parse refusal preserves failure status")
    assert(output == "", "parse refusal leaves stdout empty")
    assert(err == diagnostic .. "\n",
      "parse refusal emits diagnostic alone for " .. (argv[1] or "no arguments") .. ": " .. err)
  end
end

local function test_successful_help_keeps_its_current_output()
  local overview = flags.command_help(commands.CSPEC)
  .. "\n\n" .. doctrine.listing() .. "\n"
  for _, argv in ipairs({{"help"}, {"--help"}}) do
    local code, output, err = capture(table.unpack(argv))
    assert(code == 0 and output == overview and err == "",
      "overview help remains successful: " .. table.concat(argv, " ") .. err)
  end
  for _, argv in ipairs({{"help", "new"}, {"new", "--help"}}) do
    local code, output, err = capture(table.unpack(argv))
    assert(code == 0 and err == "", "verb help remains successful")
    assert(output == flags.command_help(commands.CSPEC, "new") .. "\n",
      "verb help retains its output")
  end
  local topic = doctrine.names()[1]
  local code, output, err = capture("help", topic)
  assert(code == 0 and err == "", "doctrine help remains successful")
  assert(output == check.must(doctrine.page(topic)) .. "\n",
    "doctrine help retains its output")
end

local function test_new_terminator_stores_dash_leading_title_verbatim()
  local s = fixture.init_state_repo("parse-terminator")
  local title = "--dash-leading title --with literal options"
  local code, output, err = capture("new", "--dir", s.root, "--", title)
  assert(code == 0 and err == "", "new accepts the terminator: " .. output .. err)
  fixture.caller_publish(s)
  local found = false
  for _, it in ipairs(check.must(store.list(check.must(store.open(s.root))))) do
    if it.title == title then found = true end
  end
  assert(found, "new stores the complete dash-leading title verbatim")
end
