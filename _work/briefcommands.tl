--- Resolved repo-mechanics commands, formatted for `_work.brief` to fill
--- `_work.brieftext`'s `BUILDER` and `_work.brieftext_review`'s
--- `REVIEW`/`REVIEW_SCRIPT` `<TYPE_CHECK_CMD>`, `<TEST_CMD>`,
--- `<TEST_CMD_PHRASE>`, `<GATE_CMD>`, and `<BOOTSTRAP_CMD>`/
--- `<BOOTSTRAP_PHRASE>` placeholders — the resolved `check-file`,
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
--- `<BOOTSTRAP_CMD>`/`<BOOTSTRAP_PHRASE>` read differently by caller: a
--- builder mid-session only ever needs to redo the build step
--- (`--check types` resolves a moved sibling against the LAST BUILD's
--- snapshot), never a re-fetch, so `BOOTSTRAP_CMD` is the resolved
--- bootstrap plan's own last step alone; a fresh review checkout has no
--- `o/3p` cache at all, so `BOOTSTRAP_PHRASE` is the whole plan, every
--- step in order, plus its own trailing "before you run any test"
--- prose — the two are separate keys, not one value read two ways,
--- because the fallback sentences they carry do not share a shape.
--- `<TEST_CMD_PHRASE>` is likewise a full backtick-quoted clause (the
--- test-file command plus its own `<file>`, or, unresolved, the
--- original two-branch "in cosmic, ... in work" sentence) for a
--- template spot that cannot just wrap a bare `TEST_CMD` in its own
--- backticks.
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
"`bin/cosmic --make ci` for cosmic;\n   `make -j$(nproc) o//tool/lua/test` for cosmopolitan"
local FALLBACK_TEST_PHRASE < const > =
"`bin/cosmic --make test <file>` in cosmic,\n`bin/cosmic --make test _work/<file>` in work"
local FALLBACK_BUILDER_BOOTSTRAP < const > = "--make build"
local FALLBACK_REVIEW_BOOTSTRAP_PHRASE < const > =
"`bin/cosmic --make fetch` before its first test, and `--make build` once if\nyou run any test."

--- Resolve the commands for one item's repo checkout.
--- @param checkout string The item's local repo checkout, "" when unresolved
--- @param kind string "builder" or "review" — which of `<BOOTSTRAP_CMD>`
--- (builder: the plan's last step alone) or `<BOOTSTRAP_PHRASE>` (review:
--- the whole plan, plus its own trailing prose) to render
--- @return {string: string} TYPE_CHECK_CMD, TEST_CMD, GATE_CMD,
--- TEST_CMD_PHRASE, and either BOOTSTRAP_CMD (builder) or BOOTSTRAP_PHRASE
--- (review)
local function commands(checkout: string, kind: string): {string: string}
  local prof = repoprofile.resolve(checkout)
  if prof.kind == "absent" then
    local out: {string: string} = {
      TYPE_CHECK_CMD = FALLBACK_TYPE_CHECK,
      TEST_CMD = FALLBACK_TEST,
      GATE_CMD = FALLBACK_GATE,
      TEST_CMD_PHRASE = FALLBACK_TEST_PHRASE,
    }
    if kind == "review" then
      out.BOOTSTRAP_PHRASE = FALLBACK_REVIEW_BOOTSTRAP_PHRASE
    else
      out.BOOTSTRAP_CMD = FALLBACK_BUILDER_BOOTSTRAP
    end
    return out
  end
  local test_cmd = base_command(prof.test_file)
  local out: {string: string} = {
    TYPE_CHECK_CMD = base_command(prof.check_file),
    TEST_CMD = test_cmd,
    GATE_CMD = "`" .. joined(prof.gate) .. "`",
    TEST_CMD_PHRASE = "`" .. test_cmd .. " <file>`",
  }
  if kind == "review" then
    out.BOOTSTRAP_PHRASE = bootstrap_plan(prof.bootstrap) .. " before you run any test."
  elseif #prof.bootstrap > 0 then
    out.BOOTSTRAP_CMD = joined(prof.bootstrap[#prof.bootstrap])
  else
    out.BOOTSTRAP_CMD = ""
  end
  return out
end

local record briefcommands
  commands: function(checkout: string, kind: string): {string: string}
end

local M: briefcommands = {
  commands = commands,
}

return M
