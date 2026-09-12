--- Resolved repo-mechanics commands, as the typed fields `_work.brief`
--- carries into `_work.brieftext`'s `BUILDER` and
--- `_work.brieftext_review`'s `REVIEW`/`REVIEW_SCRIPT` — the resolved
--- `check-file`, `test-file`, `gate`, and `bootstrap` commands
--- `_work.repoprofile` already builds, regardless of whether they came
--- from the `cosmic` convention or a `make` kind's own targets. When
--- the resolver cannot place the item's repo (no local checkout
--- mapped, or the checkout carries neither a `cosmic` nor a `make`
--- marker), every value falls back to the literal `cosmic`-specific
--- text the templates carried before this module existed — unchanged
--- rendered output for `cosmic-lua/cosmic` and, until its Makefile
--- advertises the four targets, `cosmic-lua/cosmopolitan`.
---
--- `bootstrap_cmd`/`bootstrap_phrase` read differently by caller: a
--- builder mid-session only ever needs to redo the build step
--- (`--check types` resolves a moved sibling against the LAST BUILD's
--- snapshot), never a re-fetch, so `bootstrap_cmd` is the resolved
--- bootstrap plan's own last step alone; a fresh review checkout has no
--- `o/3p` cache at all, so `bootstrap_phrase` is the whole plan, every
--- step in order, plus its own trailing "before you run any test"
--- prose — the two are separate fields, not one value read two ways,
--- because the fallback sentences they carry do not share a shape, and
--- each is nil for the caller kind that does not ask for it.
--- `type_check_cmd`, `test_cmd`, and `test_cmd_phrase` are each a
--- full backtick-quoted command with its own file argument already
--- filled in (a positional argument for `cosmic`, a `FILE=<file>`
--- make-variable token for `make`) — never a bare command for a
--- template to append a file suffix to itself, which is exact only for
--- `cosmic`'s positional convention and silently wrong for `make`'s.
--- `test_cmd_phrase` differs from `test_cmd` only in which file
--- text is filled in: the generic `<file>` placeholder, or, unresolved,
--- the original two-branch "in cosmic, ... in work" sentence — a
--- template spot that names no worked example path of its own.
local repoprofile = require("_work.repoprofile")

--- The commands one item's repo resolves to, named for the template
--- fields they answer. `bootstrap_cmd` is present for a builder and
--- `bootstrap_phrase` for a review; the other is nil, because neither
--- kind's template declares it.
local record Commands
  type_check_cmd: string
  test_cmd: string
  gate_cmd: string
  test_cmd_phrase: string
  bootstrap_cmd: string | nil
  bootstrap_phrase: string | nil
end

--- Render `argv` as one displayable command line.
--- @param argv {string} The command and its arguments
--- @return string The space-joined command
local function joined(argv: {string}): string
  return table.concat(argv, " ")
end

--- The full `check_file`/`test_file` command with `file` filled in,
--- exactly as `_work.repoprofile` builds it for the resolved kind — a
--- trailing positional argument for `cosmic`, a `FILE=<file>`
--- make-variable token for `make`. `file` is prose read by a builder or
--- reviewer, never executed, so passing the literal placeholder text
--- (`"<file>"`, or a worked example path) straight through renders the
--- real, runnable shape for either kind with no separate suffix a
--- template would have to append itself — appending one unconditionally
--- was exact only for `cosmic`'s positional convention and silently
--- broke `make`'s `FILE=` one.
--- @param build function(file: string): {string} `check_file` or `test_file`
--- @param file string The file text to fill in — a placeholder or an
--- example path, always literal prose
--- @return string The command backtick-quoted, "" if the builder returns
--- nothing (an unadvertised `make` capability)
local function full_command(build: function(file: string): {string}, file: string): string
  local argv = build(file)
  if #argv == 0 then return "" end
  return "`" .. joined(argv) .. "`"
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

--- The worked example path the "between edits" ratchet-fix paragraph
--- names, in both the resolved `test_cmd` and its unresolved fallback.
local EXAMPLE_TEST_FILE < const > = "_build/<name>_test.tl"

local FALLBACK_TYPE_CHECK < const > = "`bin/cosmic --check types <file>`"
local FALLBACK_TEST < const > = "`bin/cosmic --make test " .. EXAMPLE_TEST_FILE .. "`"
local FALLBACK_GATE < const > =
"`bin/cosmic --make ci` for cosmic;\n   `make -j$(nproc) o//tool/lua/test` for cosmopolitan"
local FALLBACK_TEST_PHRASE < const > =
"`bin/cosmic --make test <file>` in cosmic,\n`bin/cosmic --make test _work/<file>` in work"
local FALLBACK_BUILDER_BOOTSTRAP < const > = "--make build"
local FALLBACK_REVIEW_BOOTSTRAP_PHRASE < const > =
"`bin/cosmic --make fetch` before its first test, and `--make build` once if\nyou run any test."

--- Resolve the commands for one item's repo checkout.
--- @param checkout string The item's local repo checkout, "" when unresolved
--- @param kind string "builder" or "review" — which of `bootstrap_cmd`
--- (builder: the plan's last step alone) or `bootstrap_phrase` (review:
--- the whole plan, plus its own trailing prose) to render
--- @return Commands The resolved commands
local function commands(checkout: string, kind: string): Commands
  local prof = repoprofile.resolve(checkout)
  if prof.kind == "absent" then
    local out: Commands = {
      type_check_cmd = FALLBACK_TYPE_CHECK,
      test_cmd = FALLBACK_TEST,
      gate_cmd = FALLBACK_GATE,
      test_cmd_phrase = FALLBACK_TEST_PHRASE,
    }
    if kind == "review" then
      out.bootstrap_phrase = FALLBACK_REVIEW_BOOTSTRAP_PHRASE
    else
      out.bootstrap_cmd = FALLBACK_BUILDER_BOOTSTRAP
    end
    return out
  end
  local out: Commands = {
    type_check_cmd = full_command(prof.check_file, "<file>"),
    test_cmd = full_command(prof.test_file, EXAMPLE_TEST_FILE),
    gate_cmd = "`" .. joined(prof.gate) .. "`",
    test_cmd_phrase = full_command(prof.test_file, "<file>"),
  }
  if kind == "review" then
    out.bootstrap_phrase = bootstrap_plan(prof.bootstrap) .. " before you run any test."
  elseif #prof.bootstrap > 0 then
    out.bootstrap_cmd = joined(prof.bootstrap[#prof.bootstrap])
  else
    out.bootstrap_cmd = ""
  end
  return out
end

local record briefcommands
  type Commands = Commands
  commands: function(checkout: string, kind: string): Commands
end

local M: briefcommands = {
  commands = commands,
}

return M
