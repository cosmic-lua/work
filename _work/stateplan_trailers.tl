--- Git trailer grammar with every ambient configuration source disabled.
--- A commit message is newline-terminated, and `interpret-trailers` only
--- separates a trailer block from a subject that already ends in one: given
--- `"new pending"` it appends the reserved trailers straight onto that line,
--- where its own `--parse` no longer reads them as trailers at all. So every
--- message is normalised to exactly one trailing newline before either
--- direction runs, which also makes `bind` idempotent on a message it
--- already bound.
local git = require("_work.singlehead_git")

--- @param message string A commit message, terminated or not
--- @return string The same message with exactly one trailing newline
local function terminated(message: string): string
  return (message:gsub("\n*$", "")) .. "\n"
end

--- @param message string The commit message to read or rewrite
--- @param args {string} Arguments after `interpret-trailers`
--- @return string | nil The command's stdout
--- @return string Error message
local function run(message: string, args: {string}): string | nil, string
  local argv: {string} = {"--git-dir=/dev/null", "-c", "core.commentChar=#",
    "-c", "trailer.separators=:", "interpret-trailers", "--where", "end", "--no-divider"}
  for _, argument in ipairs(args) do argv[#argv + 1] = argument end
  return git.run(".", argv, terminated(message), {GIT_CONFIG = "/dev/null", GIT_CONFIG_GLOBAL = "/dev/null",
      GIT_CONFIG_SYSTEM = "/dev/null", GIT_CONFIG_NOSYSTEM = "1", GIT_CONFIG_COUNT = "0", GIT_CONFIG_PARAMETERS = ""})
end

--- @param message string The commit message to read
--- @return string | nil Its trailer block, one `Key: value` per line
--- @return string Error message
local function parse(message: string): string | nil, string
  return run(message, {"--parse"})
end

local record Module
  parse: function(string): string | nil, string
end
local M: Module = {parse = parse}
return M
