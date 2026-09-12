#!/usr/bin/env cosmic
-- The doctrine pages: every listed topic renders, the listing names
-- them all, `help <topic>` serves a page through the real dispatch,
-- and no topic name shadows a verb — the intercept runs before the
-- command dispatcher, so a collision would silently eat a verb's own
-- help page.

local doctrine = require("_work.doctrine")
local fs = require("cosmic.fs")
local gitboard = require("_work.gitboard")

--- Run gitboard.main(...) and capture exactly what it prints via
--- print() — the swap-and-restore pattern gitboard_test.tl uses.
--- @param ... string Arguments to pass to gitboard.main, as on argv
--- @return integer gitboard.main's exit code
--- @return string Every print()'d line, newline-joined
local function gitboard_and_capture(...: string): integer, string
  local old_print = _G.print
  local lines: {string} = {}
  _G.print = function(...: any)
    local parts: {string} = {}
    for i = 1, select("#", ...) do
      parts[i] = tostring((select(i, ...)))
    end
    lines[#lines + 1] = table.concat(parts, "\t")
  end
  local ok, result = pcall(gitboard.main, ...)
  _G.print = old_print
  if not ok then
    error(result, 0)
  end
  return result, table.concat(lines, "\n")
end

local function test_bar_requires_an_existing_row_migration_plan()
  local code, out = gitboard_and_capture("help", "bar")
  assert(code == 0, out)
  local flat = out:gsub("%s+", " ")
  assert(flat:find(
      "A `## Change` that alters the shape of a committed tracking file "
      .. "(a TSV, a baseline `.tl`, or a `.cosmic-*` floor) states how its "
      .. "existing rows reach the new shape: a first-run migration the "
      .. "change performs, an exact one-off command, or a rewrite committed "
      .. "with the change. The caller checks this before building; a missing "
      .. "plan means stop and refine the spec, not invent a bridge.", 1, true) ~= nil,
    "help bar must require an existing-row plan and caller refinement: " .. out)
end

local function test_every_topic_renders()
  local names = doctrine.names()
  assert(#names >= 5, "the system ships at least its five pages")
  for _, name in ipairs(names) do
    local page = doctrine.page(name)
    assert(page ~= nil and #page > 200,
      ("topic %s renders a real page"):format(name))
    assert(page:sub(1, #name) == name,
      ("a page opens with its own name: %s"):format(name))
  end
  assert(doctrine.page("no-such-topic") == nil,
    "a name that is not a topic is nil, not a guess")
end

local function test_listing_names_every_topic()
  local listing = doctrine.listing()
  for _, name in ipairs(doctrine.names()) do
    assert(listing:find(name, 1, true) ~= nil,
      ("the listing names %s"):format(name))
  end
end

local function test_help_serves_a_topic_through_the_dispatch()
  local code, out = gitboard_and_capture("help", "system")
  assert(code == 0, "help <topic> exits clean")
  assert(out:find("finishing beats starting", 1, true) ~= nil,
    "the system page came through the real dispatch: " .. out:sub(1, 80))
end

local function test_help_overview_lists_the_topics()
  local code, out = gitboard_and_capture("help")
  assert(code == 0)
  assert(out:find("topics ('gitboard help <topic>')", 1, true) ~= nil,
    "the overview carries the topic list")
end

local function test_offline_help_walks_the_authority_and_one_push_workflow()
  local code, out = gitboard_and_capture("help", "offline")
  assert(code == 0)
  local claim = assert(out:find("gitboard claim A B C", 1, true))
  local authority = assert(out:find("PREPARED and PUSHED grant no authority", 1, true))
  local begin = assert(out:find("gitboard draft begin", 1, true))
  local show = assert(out:find("gitboard draft show", 1, true))
  local publish = assert(out:find("gitboard publish", begin, true))
  assert(claim < authority and authority < begin and begin < show and show < publish,
    "offline help presents claim confirmation before draft composition and publication")
  assert(out:find("one atomic push", 1, true), out)
  assert(out:find("never discovers", 1, true), out)
  assert(out:find("parentless immutable claim-batch commit", 1, true), out)
  assert(out:find("refs/heads/claim-batches/<batch-id>", 1, true), out)
  assert(out:find("each bridge tree stores only the batch SHA", 1, true), out)
  assert(out:find("batch ref and every first-parent", 1, true), out)
  assert(out:find("including this caller's claim", 1, true), out)
  assert(out:find("separate `renew` and `drop`", 1, true), out)
end

local function test_claim_doctrine_has_no_partial_batch_or_take_acquisition()
  local system = assert(doctrine.page("system"))
  local build = assert(doctrine.page("build"))
  local orchestrate = assert(doctrine.page("orchestrate"))
  assert(system:find("One parentless immutable batch", 1, true), system)
  assert(build:find("Claim it (`claim ID`)", 1, true), build)
  assert(orchestrate:find("one parentless immutable batch", 1, true), orchestrate)
  assert(orchestrate:find("succeed for different subsets", 1, true) == nil,
    "claim batches never expose partial authority")
  assert(orchestrate:find("`take ID`, then `worktree ID`", 1, true) == nil,
    "take is handover, never acquisition")
end

local function test_bar_states_the_ready_when_convention()
  local page = doctrine.page("bar")
  assert(page ~= nil, "the bar topic renders")
  assert(page:find("Ready when:", 1, true) ~= nil,
    "the bar topic names the Ready when convention")
  assert(page:find("\"Ready\nwhen: `CMD` prints `OUT`.\"", 1, true) ~= nil,
    "the bar topic states the evaluated shape")
  assert(page:find(
      "`next` skips a not-ready head and offers the\n"
      .. "next candidate instead. A direct claim is only a lease",
      1, true) ~= nil,
    "next checks readiness while a direct claim remains only a lease")
end

local function test_bar_forbids_a_change_with_two_mechanisms()
  local page = doctrine.page("bar")
  assert(page ~= nil, "the bar topic renders")
  assert(page:find("one mechanism, never two", 1, true) ~= nil,
    "the bar topic bars a Change that offers two mechanisms")
end

local function test_bar_requires_a_grep_hit_for_a_named_location()
  local page = doctrine.page("bar")
  assert(page ~= nil, "the bar topic renders")
  assert(page:find("quotes the `grep -n` hit", 1, true) ~= nil,
    "the bar topic requires a grep -n hit for a named function or string")
end

local function test_bar_requires_an_anchor_string_for_any_file_line_citation()
  local page = doctrine.page("bar")
  assert(page ~= nil, "the bar topic renders")
  local flat = page:gsub("%s+", " ")
  assert(flat:find(
      "The same rule covers any bare file:line citation of quoted "
      .. "source text, wherever it sits", 1, true) ~= nil,
    "the bar topic extends the grep-hit requirement past function/string "
    .. "placements to every file:line citation")
  assert(flat:find(
      "an `## Evidence` paragraph citing a fact as much as `## Change` "
      .. "naming a function", 1, true) ~= nil,
    "the bar topic names ## Evidence explicitly, not only ## Change")
  assert(flat:find(
      "Before: `_work/example.tl:54-56` beside the quoted sentence. "
      .. "After: the same quote plus "
      .. "`grep -n \"the quoted phrase\" _work/example.tl`", 1, true) ~= nil,
    "the bar topic gives a before/after worked example")
  assert(flat:find(
      "A citation with a number but no anchor string is under the bar "
      .. "the same way an unmeasured claim already is", 1, true) ~= nil,
    "a number-only citation is under the bar like an unmeasured claim")
end

local function test_bar_requires_the_three_wiring_files_named()
  local page = doctrine.page("bar")
  assert(page ~= nil, "the bar topic renders")
  assert(page:find("lists its three wiring files", 1, true) ~= nil,
    "the bar topic requires a verb or flag Change to name its wiring files")
end

local function test_bar_requires_the_pattern_and_its_find_count()
  local page = doctrine.page("bar")
  assert(page ~= nil, "the bar topic renders")
  assert(page:find(
      "A Change over N sites states the PATTERN that\n"
      .. "selects them and the count `cosmic --find PATTERN [PATH...]` printed\n"
      .. "— never a list of file:line pairs a builder re-derives.",
      1, true) ~= nil,
    "the bar topic states the PATTERN and its --find count, unconditionally")
end

local function test_bar_requires_a_sweeps_own_pasted_dry_run_output()
  local page = doctrine.page("bar")
  assert(page ~= nil, "the bar topic renders")
  assert(page:find(
      "A Change\nwhose acceptance is a sweep — a `--rewrite … --apply`, a `--fix`,\n"
      .. "any command whose output is the diff — pastes that command's own\n"
      .. "output from a dry run at spec time: the `applied`/`refused` line, or\n"
      .. "the refusal, not only the `--find` count that named its sites.",
      1, true) ~= nil,
    "the bar topic requires a sweep Change to paste its own dry-run output")
  assert(page:find(
      "A\npaste of `0 applied` or a refusal is itself proof the spec is not\n"
      .. "ready — the sweep found nothing to change, or would not run at all.",
      1, true) ~= nil,
    "the bar topic treats a 0-applied or refused paste as not ready")
end

local function test_build_mirrors_the_ready_when_convention()
  local page = doctrine.page("build")
  assert(page ~= nil, "the build topic renders")
  assert(page:find(
      "including `Ready when`, before\n   building",
      1, true) ~= nil,
    "step 2 makes direct claim callers recheck readiness")
end

--- The first paragraph of a `---`-commented module header: lines up
--- to the first bare `---` separator, the `--- ` prefix stripped and
--- rewrapped onto one line — so it compares to a doctrine page's own
--- first paragraph once that is collapsed the same way.
--- @param source string The module's full source text
--- @return string The paragraph, one line, single-spaced
local function header_first_paragraph(source: string): string
  local out: {string} = {}
  for line in (source .. "\n"):gmatch("(.-)\n") do
    if line == "---" then
      break
    end
    local stripped = line:match("^%-%-%- ?(.*)$")
    if stripped == nil then
      break
    end
    out[#out + 1] = stripped
  end
  return table.concat(out, " ")
end

--- A page body's first paragraph: up to its first blank line, its own
--- line breaks collapsed to spaces.
--- @param body string The page body, past its "name — title" header
--- @return string The paragraph, one line, single-spaced
local function body_first_paragraph(body: string): string
  local para = body:match("^(.-)\n\n") or body
  return (para:gsub("\n", " "))
end

-- `help order` IS `_work/readddl.tl`'s own definition of rank, restated
-- nowhere else: the page's first paragraph must read exactly as the
-- module header's does, so the two can never drift apart in meaning.
local function test_order_page_opens_with_ranks_own_definition()
  local page = doctrine.page("order")
  assert(page ~= nil, "the order topic renders")
  local body = page:match("\n\n(.*)$")
  assert(body ~= nil, "the page carries a body past its header")
  local source, rerr = fs.read("_work/readddl.tl")
  assert(source ~= nil, "readddl.tl reads from the tree: " .. tostring(rerr))
  local want = header_first_paragraph(source)
  local got = body_first_paragraph(body)
  assert(got == want,
    ("the order page's first paragraph must equal readddl.tl's header:\n"
      .. "want: %s\ngot:  %s"):format(want, got))
end

local function test_no_topic_shadows_a_verb()
  -- The overview's command rows are the verb vocabulary; a topic
  -- sharing a name would be served by the intercept INSTEAD of that
  -- verb's help page, so the two sets must be disjoint.
  local _, out = gitboard_and_capture("help")
  local commands: {string: boolean} = {}
  local in_commands = false
  for line in (out .. "\n"):gmatch("(.-)\n") do
    if line == "commands:" then
      in_commands = true
    elseif in_commands then
      local name = line:match("^  (%S+)")
      if name == nil then
        in_commands = false
      else
        commands[name] = true
      end
    end
  end
  assert(commands["take"], "the parse found the real command rows")
  for _, name in ipairs(doctrine.names()) do
    assert(not commands[name],
      ("topic %s shadows a verb — rename the topic"):format(name))
  end
  -- And a verb's own page still wins: `help take` is the verb's help,
  -- never a doctrine page.
  local code, verb_out = gitboard_and_capture("help", "take")
  assert(code == 0)
  assert(verb_out:find("usage:", 1, true) ~= nil,
    "help <verb> still renders the verb page: " .. verb_out:sub(1, 80))
end
