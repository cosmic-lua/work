--- Resolved repo-mechanics commands, formatted for `_work.brief` to fill
--- `_work.brieftext`'s `BUILDER` and `_work.brieftext_review`'s
--- `REVIEW`/`REVIEW_SCRIPT` `<TYPE_CHECK_CMD>`, `<TEST_CMD>`, `<GATE_CMD>`,
--- and `<BOOTSTRAP_CMD>` placeholders — the resolved `check-file`,
--- `test-file`, `gate`, and `bootstrap` commands `_work.repoprofile`
--- already builds, regardless of whether they came from the `cosmic`
--- convention or a `make` kind's own targets. When the resolver cannot
--- place the item's repo (no local checkout mapped, or the checkout
--- carries neither a `cosmic` nor a `make` marker), every value falls
--- back to the literal `cosmic`-specific text the templates carried
--- before this module existed — unchanged rendered output for
--- `cosmic-lua/cosmic` and, until its Makefile advertises the four
--- targets, `cosmic-lua/cosmopolitan`.
---
--- `<BOOTSTRAP_CMD>` reads differently by caller: a builder mid-session
--- only ever needs to redo the build step (`--check types` resolves a
--- moved sibling against the LAST BUILD's snapshot), never a re-fetch,
--- so its value is the resolved bootstrap plan's own last step; a fresh
--- review checkout has no `o/3p` cache at all, so its value is the whole
--- plan, every step in order.
local repoprofile = require("_work.repoprofile")

local SENTINEL < const > = "\0FILE\0"

--- Render `argv` as one displayable command line.
--- @param argv {string} The command and its arguments
--- @return string The space-joined command
local function joined(argv: {string}): string
  return table.concat(argv, " ")
end

--- The base command a `check_file`/`test_file` builder returns, its
--- trailing file-shaped token dropped so a template can append its own
--- `<file>` in prose. The sentinel can only appear inside that trailing
--- token — a direct file argument, or `make`'s `FILE=<file>` token — so
--- dropping every token containing it is exact for both shapes
--- `_work.repoprofile` builds.
--- @param build function(file: string): {string} `check_file` or `test_file`
--- @return string The command with no file argument, "" if the builder
--- returns nothing (an unadvertised `make` capability)
local function base_command(build: function(file: string): {string}): string
  local argv = build(SENTINEL)
  local out: {string} = {}
  for _, token in ipairs(argv) do
    if token:find(SENTINEL, 1, true) == nil then
      out[#out + 1] = token
    end
  end
  return joined(out)
end

--- Every bootstrap step, in order, each its own backtick-quoted command.
--- @param steps {{string}} The resolved bootstrap plan
--- @return string The steps joined by "and", "" if the plan is empty
local function bootstrap_plan(steps: {{string}}): string
  local parts: {string} = {}
  for _, argv in ipairs(steps) do
    parts[#parts + 1] = "`" .. joined(argv) .. "`"
  end
  return table.concat(parts, " and ")
end

local FALLBACK_TYPE_CHECK < const > = "bin/cosmic --check types"
local FALLBACK_TEST < const > = "bin/cosmic --make test"
local FALLBACK_GATE < const > =
"`bin/cosmic --make ci` for cosmic; `make -j$(nproc) o//tool/lua/test` for cosmopolitan"
local FALLBACK_BUILDER_BOOTSTRAP < const > = "--make build"
local FALLBACK_REVIEW_BOOTSTRAP < const > =
"`bin/cosmic --make fetch` and `bin/cosmic --make build`"

--- Resolve the four commands for one item's repo checkout.
--- @param checkout string The item's local repo checkout, "" when unresolved
--- @param kind string "builder" or "review" — which `<BOOTSTRAP_CMD>`
--- phrasing to render
--- @return {string: string} TYPE_CHECK_CMD, TEST_CMD, GATE_CMD, BOOTSTRAP_CMD
local function commands(checkout: string, kind: string): {string: string}
  local prof = repoprofile.resolve(checkout)
  if prof.kind == "absent" then
    return {
      TYPE_CHECK_CMD = FALLBACK_TYPE_CHECK,
      TEST_CMD = FALLBACK_TEST,
      GATE_CMD = FALLBACK_GATE,
      BOOTSTRAP_CMD = kind == "review" and FALLBACK_REVIEW_BOOTSTRAP
      or FALLBACK_BUILDER_BOOTSTRAP,
    }
  end
  local bootstrap = ""
  if kind == "review" then
    bootstrap = bootstrap_plan(prof.bootstrap)
  elseif #prof.bootstrap > 0 then
    bootstrap = joined(prof.bootstrap[#prof.bootstrap])
  end
  return {
    TYPE_CHECK_CMD = base_command(prof.check_file),
    TEST_CMD = base_command(prof.test_file),
    GATE_CMD = "`" .. joined(prof.gate) .. "`",
    BOOTSTRAP_CMD = bootstrap,
  }
end

local record briefcommands
  commands: function(checkout: string, kind: string): {string: string}
end

local M: briefcommands = {
  commands = commands,
}

return M
