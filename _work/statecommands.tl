--- Native storage commands share the ordinary board command table.
local flags = require("cosmic.flags")

local function extend(spec: flags.CommandSpec)
  spec.commands[#spec.commands + 1] = {name = "migrate6",
    summary = "prepare and audit a frozen native-board migration",
    spec = {usage = "plan | show | verify-source [options]",
      summary = "plan creates a checkpoint and native candidate locally. It does not publish or "
      .. "activate the board. Source drift refuses a resume. Live activation requires an enforced "
      .. "legacy-write freeze and a complete source-ref recheck. See help native.",
      flags = {
        {long = "dir", arg = "DIR", default = os.getenv("GITBOARD_DIR") or ".", help = "source board checkout"},
        {long = "checkpoint", arg = "FILE.literal", help = "frozen migration checkpoint (default o/migrate6/checkpoint.literal)"},
        {long = "prefix", arg = "REFS/", help = "source namespace; default canonical local or remote board refs"},
        {long = "catch-up", help = "append newly observed legacy history before native writes begin"}}}}
end

local record statecommands
  extend: function(spec: flags.CommandSpec)
end
local M: statecommands = {extend = extend}
return M
