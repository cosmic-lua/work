#!/usr/bin/env cosmic
-- What `show` prints for one item. The output is what a session reads
-- to decide, so the words are the contract — asserted here on the pure
-- report the `cmd_show` wrapper prints: fields, derived state, the
-- take gate's problem list, the sidecar, the git history.

local check = require("cosmic.check")
local commit_flow = require("_work.commit_flow_fixture")
local eventsmod = require("_work.events")
local fixture = require("_work.fixture")
local gitreadspec = require("_work.gitreadspec")
local itemtree = require("_work.itemtree")
local item = require("_work.item")
local ksuid = require("_work.ksuid")
local publish = require("_work.publish")
local read = require("_work.read")
local show = require("_work.gitshow")
local store = require("_work.store")
local tail = require("_work.tail")

local init_state_repo = fixture.init_state_repo
local file_item = fixture.file_item
local give_spec = fixture.give_spec

local seq = 0

--- A deterministic id; later calls sort later.
local function next_id(): string
  seq = seq + 1
  return check.must(ksuid.encode(1700000000 + seq, ("\0"):rep(16)))
end

local BOARD < const > = next_id()
local ROOT < const > = next_id()
local UNDER < const > = next_id()
local WORK < const > = next_id()
local ADRIFT < const > = next_id()
local BEATEN < const > = next_id()
local BASE < const > = ("a"):rep(40)
local HEAD < const > = ("b"):rep(40)

--- A spec sidecar whose last section ends at a thematic break.
local SIDECAR < const > = table.concat({
    "## Change", "add the verb", "",
    "---", "a footer below the break", "",
  }, "\n")

--- Whether any line matches a Lua pattern.
local function matched(lines: {string}, pattern: string): boolean
  for _, line in ipairs(lines) do
    if line:match(pattern) then
      return true
    end
  end
  return false
end

--- The board, an outcome under it with a container holding one
--- claimed build, a fresh todo leaf, and a second, unranked outcome.
--- Appended last so every existing index (`all[1]` through `all[5]`)
--- keeps naming what it always did.
local function a_board(): {item.Item}
  return {
    check.must(item.decode({id = ROOT, title = "an outcome", parent = BOARD})),
    check.must(item.decode({id = UNDER, title = "a container", parent = ROOT})),
    check.must(item.decode({id = WORK, title = "a slice", parent = UNDER,
          claim = "session-a", claim_base = BASE, handover_head = HEAD,
          builders = "session-a"})),
    check.must(item.decode({id = ADRIFT, title = "a fresh leaf",
          parent = ROOT})),
    check.must(item.decode({id = BEATEN, title = "a lesser outcome", parent = BOARD})),
    check.must(item.decode({id = BOARD, title = "board"})),
  }
end

--- `show.show_report`, over an in-memory index built from `all` — role,
--- rank and state are read through the same `_work.read`/`_work.gitshow`
--- functions `cmd_show` calls, so this pins the whole render path, not
--- a hand-picked stand-in for it.
--- @param it item.Item The item to render
--- @param all {item.Item} Every item
--- @param body string Its spec sidecar, "" when it has none
--- @param events {publish.Event} Its git history, newest first
--- @param problems {string} The take gate's problem list, possibly empty
--- @param overlaps {string} | nil `_work.overlap`'s pre-rendered lines
--- @param ci_state string | nil `show.show_report`'s own CI state input
--- @param ci_head string | nil `show.show_report`'s own CI head input
--- @param ci_age_s integer | nil `show.show_report`'s own CI age input
--- @return {string} The lines to print
--- @return string The verdict detail
local function report_for(it: item.Item, all: {item.Item}, body: string,
    events: {publish.Event}, problems: {string}, overlaps?: {string},
    ci_state?: string, ci_head?: string, ci_age_s?: integer): {string}, string
  -- `it` rides along in the index too: `read.role`/`describe`/`state_of`
  -- below query rows keyed by ITS OWN id, not only its ancestors', so a
  -- caller testing a standalone item never part of `all` (a handover
  -- scenario built just for this render, say) needs it indexed same
  -- as any other.
  local indexed = all
  local present = false
  for _, existing in ipairs(all) do
    if existing.id == it.id then
      present = true
      break
    end
  end
  if not present then
    indexed = {}
    for _, existing in ipairs(all) do
      indexed[#indexed + 1] = existing
    end
    indexed[#indexed + 1] = it
  end
  local c = fixture.make_index(indexed)
  local role = check.must(read.role(c, it.id))
  local rank_line = check.must(show.describe(c, it))
  local state = check.must(show.state_of(c, it))
  local child_rows = check.must(read.children(c, it.id))
  local by_id = item.by_id(all)
  local children_lines: {string} = {}
  for _, ch in ipairs(child_rows) do
    if ch.open then
      local title = ""
      local child_it = by_id[ch.child]
      if child_it ~= nil then
        title = child_it.title
      end
      children_lines[#children_lines + 1] = ("  %s %s"):format(
        tail.handle(ch.child), title)
    end
  end
  return show.show_report(it, role, rank_line, state, body, events, problems,
    children_lines, overlaps, nil, ci_state, ci_head, ci_age_s)
end

local function test_show_prints_fields_role_and_history()
  local all = a_board()
  local events: {publish.Event} = {
    {sha = "abc1234", at = "2026-08-17T00:00:00Z", subject = "move it"},
  }
  local lines, verdict = report_for(all[3], all, "## Change\ndo it\n",
    events, {})
  assert(lines[1] == tail.handle(WORK) .. " a slice [" .. WORK .. "]",
    "the header carries the wrapped handle and the full id: " .. lines[1])
  assert(matched(lines, "^role: work$"), table.concat(lines, "\n"))
  assert(matched(lines, "^state: review$"), "its state")
  assert(matched(lines, "^handover: " .. HEAD .. "$"), "its exact handover")
  assert(matched(lines, "^%-%-%- spec %-%-%-$"), "the sidecar is the spec")
  assert(matched(lines, "abc1234 move it"), "git log IS the item's history")
  assert(verdict == WORK:sub(1, 8) .. " is review", verdict)
end

-- `repo` and `base` render on their own field lines, base right after
-- repo, and neither prints when the item carries none.
local function test_show_prints_repo_and_base()
  local all = a_board()
  local scoped = check.must(item.decode({id = WORK, title = "a slice",
        parent = UNDER, repo = "whilp/cosmopolitan", base = "release"}))
  local lines = report_for(scoped, all, "", {}, {})
  assert(matched(lines, "^repo: whilp/cosmopolitan$"), table.concat(lines, "\n"))
  assert(matched(lines, "^base: release$"), table.concat(lines, "\n"))

  local plain = report_for(all[3], all, "", {}, {})
  assert(not matched(plain, "^repo:"), "no repo, no line")
  assert(not matched(plain, "^base:"), "no base, no line")
end

-- Provider observations are never part of the board report, even if a legacy
-- caller supplies compatibility arguments to the pure rendering function.
local function test_show_ignores_legacy_ci_arguments()
  local all = a_board()
  local lines = report_for(all[3], all, "", {}, {}, nil, "green",
    "cafef00dabc", 125)
  assert(not matched(lines, "^ci:"), table.concat(lines, "\n"))
end

local function test_show_prints_no_ci_without_legacy_arguments()
  local all = a_board()
  local lines = report_for(all[3], all, "", {}, {})
  assert(not matched(lines, "^ci:"), table.concat(lines, "\n"))
end

-- A todo item carries no PR by definition (`_work.indexddl`'s `state`
-- view: `pr <> 0` alone already reads as doing), and a resolved item's
-- leftover PR field is CI's business no longer — neither prints a
-- `ci:` line, whatever `ci_state` a caller happens to pass in.
local function test_show_prints_no_ci_line_for_any_item()
  local all = a_board()
  local todo_lines = report_for(all[4], all, "", {}, {}, nil, "green")
  assert(not matched(todo_lines, "^ci:"),
    "no PR, no ci line: " .. table.concat(todo_lines, "\n"))

  local closed = check.must(item.decode({id = next_id(), title = "a merged slice",
        parent = UNDER, pr = 7, resolution = "completed"}))
  all[#all + 1] = closed
  local closed_lines = report_for(closed, all, "", {}, {}, nil, "green")
  assert(not matched(closed_lines, "^ci:"),
    "a resolved item's stale PR: " .. table.concat(closed_lines, "\n"))
end

-- The take gate's problem list renders on the read that precedes the
-- pull, one `bar:` line each — `show` absorbed the old `check` verb,
-- so what would refuse a take is nobody's surprise.
local function test_show_prints_the_take_gates_problems()
  local all = a_board()
  local problems = {"spec: Change is missing or empty",
    "it has no position in the priority order"}
  local lines = report_for(all[4], all, "", {}, problems)
  assert(matched(lines, "^bar: spec: Change is missing or empty$"),
    table.concat(lines, "\n"))
  assert(matched(lines, "^bar: it has no position"), "every problem prints")
  local clean = report_for(all[4], all, "", {}, {})
  assert(not matched(clean, "^bar:"), "no problems, no bar lines")
end

local function test_show_prints_the_reviewer_lock()
  local all = a_board()
  local under_review = check.must(item.decode({id = WORK, title = "a slice",
        parent = UNDER, claim = "session-a", pr = 42,
        reviewer = "reviewer-b"}))
  local lines = report_for(under_review, all, "", {}, {})
  assert(matched(lines, "^reviewer: reviewer%-b$"),
    "the review lock is a fact worth reading: " .. table.concat(lines, "\n"))
end

local function test_show_names_an_items_own_graph_problem()
  local all = a_board()
  local adrift = all[4]
  adrift.parent = next_id()
  local index_problems = {("parent %s does not exist"):format(adrift.parent)}
  local lines, verdict = report_for(adrift, all, "", {}, index_problems)
  assert(matched(lines, "bar: parent .* does not exist"),
    "a broken chain says so where it is read: "
    .. table.concat(lines, "\n"))
  assert(verdict:find("is todo", 1, true), verdict)
end

-- A verdict judges a head AND the spec that head is measured against,
-- and `show` is what a re-reviewer reads to decide whether there is
-- anything new to see. A rework answering a bounce on the spec moves
-- the sidecar and no commit, so the head alone cannot answer it.
-- A flagged item's `decode_problems` print beside the bar problems —
-- `decode`'s own tolerance snapshot, not something a session has to go
-- looking for elsewhere. A clean item prints no `flagged:` line at all.
local function test_show_prints_a_flagged_items_decode_problems()
  local all = a_board()
  local flagged = check.must(item.decode({id = next_id(),
        title = "broken\ntitle", parent = UNDER}))
  all[#all + 1] = flagged
  local lines = report_for(flagged, all, "", {}, {})
  assert(matched(lines, "^flagged: title must be one line"),
    table.concat(lines, "\n"))

  local clean = report_for(all[4], all, "", {}, {})
  assert(not matched(clean, "^flagged:"), "no problems, no flagged lines")
end

-- The verdict line cites the head it judged and nothing more: a spec
-- revision is no longer recorded against a verdict, so there is no
-- "moved since" half to render whatever the sidecar now says.
local function test_show_prints_a_verdict_by_the_head_it_judged()
  local all = a_board()
  local reworked = check.must(item.decode({id = WORK, title = "a slice",
        parent = UNDER, claim = "session-a", pr = 42,
        verdict = "request changes", verdict_head = "5364cc21"}))
  for _, body in ipairs({SIDECAR, SIDECAR .. "\nmore prose\n"}) do
    local lines = report_for(reworked, all, body, {}, {})
    assert(matched(lines, "^verdict: request changes %(head 5364cc21%)$"),
      table.concat(lines, "\n"))
  end
end

-- A research handover's deliverable is a board commit, so `show` prints
-- its seven hex where a diff's PR number goes, and no PR line — the two
-- never both stand.
local function test_show_prints_a_research_handovers_digest()
  local all = a_board()
  local handed = check.must(item.decode({id = next_id(), title = "a handover",
        parent = UNDER, claim = "session-a", builders = "session-a",
        result = ("abcdef0123456789"):rep(4)}))
  all[#all + 1] = handed
  local lines = report_for(handed, all, "## Change\ndo it\n", {}, {})
  assert(matched(lines, "^state: review$"), table.concat(lines, "\n"))
  assert(matched(lines, "^result: abcdef0$"),
    "the digest prints where a PR would: " .. table.concat(lines, "\n"))
  assert(not matched(lines, "^pr:"),
    "and no PR line stands beside it: " .. table.concat(lines, "\n"))
end

-- A handover's verdict carries no head — `verdict` leaves it "" for a
-- PR-less item — so the verdict line cites the recorded board commit
-- where a diff's verdict line cites the head it judged.
local function test_show_prints_a_handovers_verdict_by_result_not_head()
  local all = a_board()
  local accepted = check.must(item.decode({id = next_id(), title = "a handover",
        parent = UNDER, claim = "session-a", builders = "session-a",
        result = ("abcdef0123456789"):rep(4), verdict = "accept",
        verdict_head = ""}))
  local lines = report_for(accepted, all, SIDECAR, {}, {})
  assert(matched(lines, "^verdict: accept %(result abcdef0%)$"),
    "the board commit prints where a diff's head would: "
    .. table.concat(lines, "\n"))
end

-- `show ID` prints one `rank:` line from this module's own `describe` —
-- a ranked child names its position and its parent's handle, an
-- unranked one (its parent's list skips it) reads "unranked", and an
-- outcome reads its position among the board's other outcomes.
local function test_show_prints_the_rank_line_for_a_ranked_child()
  local all = a_board()
  all[1].order = {UNDER, ADRIFT}
  all[6].order = {ROOT}
  local lines = report_for(all[2], all, "", {}, {})
  assert(matched(lines, "^rank: 1 of 2 under .+$"), table.concat(lines, "\n"))
end

local function test_show_prints_unranked_for_a_child_missing_from_the_order()
  local all = a_board()
  all[1].order = {ADRIFT}
  all[6].order = {ROOT}
  local lines = report_for(all[2], all, "", {}, {})
  assert(matched(lines, "^rank: unranked$"), table.concat(lines, "\n"))
end

local function test_show_prints_the_rank_line_for_an_outcome()
  local all = a_board()
  all[6].order = {ROOT, BEATEN}
  local lines = report_for(all[1], all, "", {}, {})
  assert(matched(lines, "^rank: outcome 1 of 2$"), table.concat(lines, "\n"))
end

-- `show ID` lists its own open children in rank order, one line each
-- with the wrapped handle and title — a done child never appears.
local function test_show_lists_its_open_children()
  local all = a_board()
  local done_kid = check.must(item.decode({id = next_id(),
        title = "a finished slice", parent = UNDER, resolution = "completed"}))
  all[#all + 1] = done_kid
  local lines = report_for(all[2], all, "", {}, {})
  assert(matched(lines, "^children:$"), table.concat(lines, "\n"))
  assert(matched(lines, "^  " .. tail.handle(WORK) .. " a slice$"),
    "the open child is listed with its handle and title: "
    .. table.concat(lines, "\n"))
  assert(not matched(lines, "a finished slice"),
    "a done child is never listed: " .. table.concat(lines, "\n"))
end

--- Run `show.cmd_show` against a real store and capture what it
--- prints via `print()` — the swap-and-restore pattern the other verb
--- tests use.
--- @param s store.Store The store
--- @param id string The item to show
--- @return integer cmd_show's exit code
--- @return string Every print()'d line, newline-joined
local function show_and_capture(s: store.Store, id: string): integer, string
  local old_print = _G.print
  local lines: {string} = {}
  _G.print = function(...: any)
    local parts: {string} = {}
    for i = 1, select("#", ...) do
      parts[i] = tostring((select(i, ...)))
    end
    lines[#lines + 1] = table.concat(parts, "\t")
  end
  local ok, result = pcall(show.cmd_show, s, id)
  _G.print = old_print
  if not ok then
    error(result, 0)
  end
  return result, table.concat(lines, "\n")
end

-- `show ID`'s spec body comes from the same batched `read_specs` that
-- already covers every open sibling — never a standalone single-object
-- read — so it renders correctly even with that single-item path
-- (`gitreadspec.read_spec`) stubbed to fail outright.
local function test_show_id_renders_the_spec_without_gitreads_single_file_read()
  local s = init_state_repo("show-spec-from-batch")
  local id = file_item(s, "an item", "")
  give_spec(s, id)

  local real_read_spec = gitreadspec.read_spec
  gitreadspec.read_spec = function(_root: string,
      _candidates: {string}): itemtree.Spec
    error("gitreadspec.read_spec must not run: the prose should come from "
      .. "the batched read_specs", 0)
  end
  local ok, code, out = pcall(show_and_capture, s, id)
  gitreadspec.read_spec = real_read_spec
  if not ok then
    error(code, 0)
  end
  assert(code == 0, "show should still succeed: " .. tostring(out))
  assert(out:find("Do exactly this.", 1, true) ~= nil,
    "the spec body must render from the loaded batch: " .. out)
end

-- `_work.publish.history`'s `events`-cache path must render `show ID`'s
-- history block exactly as the `git log` fallback still does — the
-- one existing behavior this whole cache is forbidden from changing.
-- `_work.events.read` stubbed to nil forces the second capture onto
-- the fallback (nothing else about the board moves between the two
-- calls), so any divergence is the cache path's own, not drift in the
-- board it is reading.
local function test_show_id_history_matches_between_cache_and_git_log()
  local s = init_state_repo("show-history-both-ways")
  local id = file_item(s, "an item with history", "")
  give_spec(s, id)
  local from_cache_code, from_cache_out = show_and_capture(s, id)
  assert(from_cache_code == 0, "show should succeed from the cache")

  local real_read = eventsmod.read
  eventsmod.read = function(_root: string, _id: string): {eventsmod.Row} | nil
    return nil
  end
  local ok, code, out = pcall(show_and_capture, s, id)
  eventsmod.read = real_read
  if not ok then
    error(code, 0)
  end
  assert(code == 0, "show should still succeed from the git log fallback")
  assert(out == from_cache_out,
    "the two histories must render byte-identically:\ncache:\n" .. from_cache_out
    .. "\nfallback:\n" .. out)
end

-- The live wrapper renders the same commit-only facts as the pure report. The
-- optional URL is visibly navigation metadata and no CI cache line appears.
local function test_show_id_prints_commit_only_handover_facts()
  local s, leaf, product = commit_flow.fresh("show-commit-facts")
  assert(commit_flow.claim(s, leaf, commit_flow.BUILDER, product) == 0)
  assert(commit_flow.handover(s, leaf, commit_flow.BUILDER, product,
      product.head, "https://example.test/change/7") == 0)
  local code, out = show_and_capture(s, leaf)
  assert(code == 0, out)
  assert(out:find("\nclaim base: " .. product.base .. "\n", 1, true) ~= nil)
  assert(out:find("\nhandover: " .. product.head .. "\n", 1, true) ~= nil)
  assert(out:find("\nexternal: https://example.test/change/7 "
      .. "(navigation only)\n", 1, true) ~= nil)
  assert(out:find("\nci:", 1, true) == nil
    and out:find("\npr:", 1, true) == nil,
    "provider observations and identifiers do not render: " .. out)
end
