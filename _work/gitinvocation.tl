--- The caller-supplied GitBoard invocation a brief renders for a
--- delegated agent: one copy-pasteable command prefix, never a guessed
--- product-checkout `bin/gitboard`. Split out of `_work.brief`, which
--- sits against the file cap, so this one small pure function keeps its
--- own doc and test rather than crowding the module that fills briefs.

--- The label shown when no caller-supplied GitBoard invocation is
--- available — never a guessed `bin/gitboard` path, since that guess is
--- exactly what strands a fresh delegated agent behind a blocked network
--- bootstrap. All-caps and hyphenated so it reads unmistakably as a
--- sentinel rather than a real command, wherever it lands in a rendered
--- command line.
local UNRESOLVED < const > = "GITBOARD-INVOCATION-UNRESOLVED-ASK-THE-CALLER"

--- The one copy-pasteable prefix every board command in a brief is
--- rendered with: `cd <cwd> && <command>` when the caller supplied
--- both, so every read or mutation the brief prints already carries an
--- exact, working invocation with no path discovery or bootstrap left
--- to the delegated agent. `UNRESOLVED` otherwise — a fresh agent that
--- pastes it verbatim gets an immediate, unambiguous non-command instead
--- of a silently guessed `bin/gitboard` that resolves to a product
--- checkout and network-bootstraps.
--- @param command string The caller-supplied invocation, "" if none
--- @param cwd string The invocation's cwd, "" if none
--- @return string The prefix to splice before every verb
local function prefix(command: string, cwd: string): string
  if command == "" then return UNRESOLVED end
  return ("cd %s && %s"):format(cwd, command)
end

local record gitinvocation
  UNRESOLVED: string
  prefix: function(command: string, cwd: string): string
end

local M: gitinvocation = {
  UNRESOLVED = UNRESOLVED,
  prefix = prefix,
}

return M
