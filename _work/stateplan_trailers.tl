--- Git trailer grammar with every ambient configuration source disabled.
local git = require("_work.singlehead_git")
local function run(message: string, args: {string}): string | nil, string
  local argv: {string} = {"--git-dir=/dev/null", "-c", "core.commentChar=#",
    "-c", "trailer.separators=:", "interpret-trailers"}
  for _, argument in ipairs(args) do argv[#argv + 1] = argument end
  return git.run(".", argv, message, {GIT_CONFIG = "/dev/null", GIT_CONFIG_GLOBAL = "/dev/null",
      GIT_CONFIG_SYSTEM = "/dev/null", GIT_CONFIG_NOSYSTEM = "1", GIT_CONFIG_COUNT = "0", GIT_CONFIG_PARAMETERS = ""})
end
local function parse(message: string): string | nil, string
  return run(message, {"--parse"})
end
local function bind(message: string, id: string, author: string): string | nil, string
  return run(message, {"--if-exists", "replace", "--trailer", "Transaction: " .. id,
      "--trailer", "Gitboard-Author: " .. author})
end
local record Module
  parse: function(string): string | nil, string
  bind: function(string, string, string): string | nil, string
end
local M: Module = {parse = parse, bind = bind}
return M
