--- Native storage commands share the ordinary board command table.
local flags = require("cosmic.flags")

--- Add the native-only commands to the ordinary board command table, so
--- `migrate6` is one verb among the rest rather than a separate entry point.
--- @param spec flags.CommandSpec The command table, appended to in place
local function extend(spec: flags.CommandSpec)
  spec.commands[#spec.commands + 1] = {name = "migrate6",
    summary = "prepare, audit, and explicitly publish a frozen native-board migration",
    spec = {usage = "plan | show | verify-source | verify-remote | activation-plan | publish [options]",
      summary = "plan creates a checkpoint and native candidate locally. It does not publish or "
      .. "activate the board. Source drift refuses a resume. Live activation requires an enforced "
      .. "legacy-write freeze verified through gh and a complete source-ref recheck. "
      .. "Publication runs only with publish --execute. See help native.",
      flags = {
        {long = "dir", arg = "DIR", default = os.getenv("GITBOARD_DIR") or ".", help = "source board checkout"},
        {long = "checkpoint", arg = "FILE.literal", help = "frozen migration checkpoint (default o/migrate6/checkpoint.literal)"},
        {long = "prefix", arg = "REFS/", help = "source namespace; default canonical local or remote board refs"},
        {long = "remote", arg = "REMOTE", help = "configured migration push remote; default board remote"},
        {long = "freeze-ruleset", arg = "ID", help = "verify this GitHub ruleset before a fresh source fetch; requires authenticated gh"},
        {long = "limit", arg = "N", default = "100", help = "maximum commit interval between staged state pushes"},
        {long = "execute", help = "with publish, verify the freeze and source set, then push and activate"},
        {long = "catch-up", help = "append newly observed legacy history before native writes begin"}}}}
end

local record statecommands
  extend: function(spec: flags.CommandSpec)
end
local M: statecommands = {extend = extend}
return M
