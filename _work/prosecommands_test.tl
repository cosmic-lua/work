#!/usr/bin/env cosmic
-- Membership only: examples may deliberately leave positional arguments open.
-- Extract syntax before consulting the registry, so a typo cannot disappear.
local flags = require("cosmic.flags")
local gitcommands = require("_work.gitcommands")
local doctrine = require("_work.doctrine")
local source = require("_work.brieftmpl_source")

local function deprecated(cmd: flags.Command): boolean
  return (cmd.summary or ""):lower():find("deprecated", 1, true) ~= nil
  or (cmd.spec.summary or ""):lower():find("deprecated", 1, true) ~= nil
end

local function check_command(line: string): string
  local verb = line:match("gitboard%s+([%w_-]+)")
  if not verb then
    return ""
  end
  local found: flags.Command
  for _, cmd in ipairs(gitcommands.CSPEC.commands) do
    if cmd.name == verb then
      found = cmd
      break
    end
  end
  if verb == "help" then
    found = {name = "help", spec = {flags = {}}}
  end
  if not found then
    return "unknown verb " .. verb
  end
  if deprecated(found) then
    return "deprecated verb " .. verb
  end
  local allowed: {string: boolean} = {["--help"] = true, ["-h"] = true}
  for _, flag in ipairs(found.spec.flags or {}) do
    allowed["--" .. flag.long] = true
    if flag.short then
      allowed["-" .. flag.short] = true
    end
  end
  if found.spec.version then
    allowed["--version"] = true
  end
  -- Quoted single option tokens still name flags; prose arguments do not.
  local function quoted(value: string): string
    if value:match("^%-%-?[%w%-]+=?.*$") and not value:find("%s") then
      return value
    end
    return "ARG"
  end
  local args = line:gsub("<[^>]*>", "ARG"):gsub('"([^"]*)"', function(value: string): string
      return quoted(value)
    end):gsub("'([^']*)'", function(value: string): string
      return quoted(value)
    end)
  for flag in args:gmatch("%f[%w%-](%-%-?[%a][%w%-]*)") do
    if not allowed[flag] then
      return "invalid flag " .. flag .. " for " .. verb
    end
  end
  return ""
end

local function snippets(text: string): {string}
  local out: {string} = {}
  text = text:gsub("\\%s*\n%s*", " ")
  text = text:gsub("```[^\n]*\n(.-)```", function(code: string): string
      out[#out + 1] = code
      return ""
    end)
  text = text:gsub("~~~[^\n]*\n(.-)~~~", function(code: string): string
      out[#out + 1] = code
      return ""
    end)
  -- Inline code can wrap, unlike separate commands within a fence.
  text = text:gsub("`([^`]+)`", function(code: string): string
      if code:find("gitboard%s+[%w_-]+") then
        out[#out + 1] = code:gsub("%s+", " ")
      end
      return ""
    end)
  local block = true
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    local command = line:match("^%s*[%w/%.%-]*gitboard%s+")
    or line:match("^%s*export%s+[%w_]+=%$%(")
    if (block and command) or line:match("^usage: gitboard%s+") then
      out[#out + 1] = line
      block = true
    else
      block = line:match("^%s*$") ~= nil or line:match(":%s*$") ~= nil
    end
  end
  return out
end

local function check_text(text: string): {string}, integer
  local errors: {string} = {}
  local count = 0
  for _, block in ipairs(snippets(text)) do
    -- A fence may hold several commands; split at each executable prefix.
    for command in (block:gsub("(%f[%w]gitboard%s+)", "\n%1")):gmatch("gitboard%s+[^`\n]+") do
      count = count + 1
      local err = check_command(command)
      if err ~= "" then
        errors[#errors + 1] = err .. ": " .. command
      end
    end
  end
  return errors, count
end

local function test_unknown_verbs_flags_and_deprecation_are_rejected()
  for _, text in ipairs({"`gitboard invented ID`", "    bin/gitboard invented ID",
      "```sh\ngitboard invented ID\n```", "`gitboard take ID --invented`",
      "```\nbin/gitboard verdict ID accept \\\n --invented\n```",
      "`gitboard rank ID --before|--invented ID`", "`gitboard sync`", "`gitboard help --invented`",
      "`gitboard show ID && gitboard invented ID`",
      "`gitboard take ID '--invented'`"}) do
    local errors, count = check_text(text)
    assert(count > 0 and #errors > 0, "must reject: " .. text)
  end
end

local function test_examples_accept_placeholders_and_optional_flags()
  local errors, count = check_text([[`gitboard take ID --head SHA [--url URL]`
`bin/gitboard rank <child-id> --before|--after <sibling-id>`
```sh
bin/gitboard verdict ID accept \
  --head SHA --session SESSION
```
`gitboard spec ID <file> --base <the current
 spec above>`]])
  assert(count == 4, "must extract all four examples")
  assert(#errors == 0, table.concat(errors, "\n"))
end

local function assert_page(label: string, text: string): integer
  local errors, count = check_text(text)
  assert(#errors == 0, label .. ": " .. table.concat(errors, "\n"))
  return count
end

local function test_all_rendered_help_and_brief_commands_are_current()
  local topic_count = 0
  for _, name in ipairs(doctrine.names()) do
    local page = doctrine.page(name)
    assert(page ~= nil, "missing topic " .. name)
    topic_count = topic_count + assert_page("topic " .. name, page)
  end
  assert(topic_count >= 30, "topic extraction must cover the live examples: " .. topic_count)
  local help_count = assert_page("overview", flags.command_help(gitcommands.CSPEC))
  for _, cmd in ipairs(gitcommands.CSPEC.commands) do
    local page = flags.command_help(gitcommands.CSPEC, cmd.name)
    if deprecated(cmd) then
      -- Only the alias's OWN generated usage identity is exempt; every
      -- example in its summary and every other page remains strict.
      page = page:gsub("^[^\n]*\n", "", 1)
    end
    local count = assert_page("verb " .. cmd.name, page)
    assert(deprecated(cmd) or count >= 1, "missing usage for " .. cmd.name)
    help_count = help_count + count
  end
  assert(help_count >= #gitcommands.CSPEC.commands - 1,
    "every nondeprecated verb must contribute its rendered usage")
  local brief_count = 0
  for _, unit in ipairs(source.UNITS) do
    -- These templates contain only field interpolations. Render neutral
    -- caller data, keeping the command prefix recognizable. Fail closed if
    -- template control syntax is ever introduced instead of silently skipping.
    local rendered = unit.text:gsub("{{%.([%w_]+)}}", function(field: string): string
        if field == "gitboard_cmd" then
          return "bin/gitboard"
        end
        return "<" .. field .. ">"
      end)
    assert(not rendered:find("{{", 1, true), "unrendered template " .. unit.name)
    brief_count = brief_count + assert_page("brief " .. unit.name, rendered)
  end
  -- Review postures render no board command line (the reviewer reports a
  -- verdict envelope), so the live examples are the builder-side ones.
  assert(brief_count >= 13, "brief extraction must cover rendered examples")
end
