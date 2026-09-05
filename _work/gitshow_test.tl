#!/usr/bin/env cosmic
-- What `show` prints for one item. The output is what a session reads
-- to decide, so the words are the contract — asserted here on the pure
-- report the `cmd_show` wrapper prints: fields, derived state, the
-- take gate's problem list, the sidecar, the git history.

local check = require("cosmic.check")
local eventsmod = require("_work.events")
local fixture = require("_work.fixture")
local gitread = require("_work.gitread")
local item = require("_work.item")
local ksuid = require("_work.ksuid")
local publish = require("_work.publish")
local rank = require("_work.rank")
local show = require("_work.gitshow")
local spec = require("_work.spec")
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

local ROOT < const > = next_id()
local UNDER < const > = next_id()
local WORK < const > = next_id()
local ADRIFT < const > = next_id()
local BEATEN < const > = next_id()

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

--- A root, a container under it holding one claimed build, a fresh
--- todo leaf, and a second, unranked root.
local function a_board(): {item.Item}
  return {
    check.must(item.decode({id = ROOT, title = "an outcome"})),
    check.must(item.decode({id = UNDER, title = "a container", parent = ROOT})),
    check.must(item.decode({id = WORK, title = "a slice", parent = UNDER,
          claim = "session-a", pr = 42})),
    check.must(item.decode({id = ADRIFT, title = "a fresh leaf",
          parent = ROOT})),
    check.must(item.decode({id = BEATEN, title = "a lesser outcome"})),
  }
end

--- `a_board()`'s rank map with no root ranking recorded — every
--- assertion below that is not itself about the `rank:` line is
--- indifferent to its exact text.
--- @param all {item.Item} Every item
--- @return {string: rank.Rank} Rank by item id
local function board_ranks(all: {item.Item}): {string: rank.Rank}
  return rank.positions(all, {})
end

local function test_show_prints_fields_role_and_history()
  local all = a_board()
  local events: {publish.Event} = {
    {sha = "abc1234", at = "2026-08-17T00:00:00Z", subject = "move it"},
  }
  local lines, verdict = show.show_report(all[3], all, board_ranks(all), "## Change\ndo it\n",
    events, {})
  assert(lines[1] == tail.handle(WORK) .. " a slice [" .. WORK .. "]",
    "the header carries the wrapped handle and the full id: " .. lines[1])
  assert(matched(lines, "^role: work$"), table.concat(lines, "\n"))
  assert(matched(lines, "^state: review$"), "its state")
  assert(matched(lines, "^pr: #42$"), "its PR")
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
  local lines = show.show_report(scoped, all, board_ranks(all), "", {}, {})
  assert(matched(lines, "^repo: whilp/cosmopolitan$"), table.concat(lines, "\n"))
  assert(matched(lines, "^base: release$"), table.concat(lines, "\n"))

  local plain = show.show_report(all[3], all, board_ranks(all), "", {}, {})
  assert(not matched(plain, "^repo:"), "no repo, no line")
  assert(not matched(plain, "^base:"), "no base, no line")
end

-- The take gate's problem list renders on the read that precedes the
-- pull, one `bar:` line each — `show` absorbed the old `check` verb,
-- so what would refuse a take is nobody's surprise.
local function test_show_prints_the_take_gates_problems()
  local all = a_board()
  local problems = {"spec: Change is missing or empty",
    "it has no position in the priority order"}
  local lines = show.show_report(all[4], all, board_ranks(all), "", {}, problems)
  assert(matched(lines, "^bar: spec: Change is missing or empty$"),
    table.concat(lines, "\n"))
  assert(matched(lines, "^bar: it has no position"), "every problem prints")
  local clean = show.show_report(all[4], all, board_ranks(all), "", {}, {})
  assert(not matched(clean, "^bar:"), "no problems, no bar lines")
end

local function test_show_prints_the_reviewer_lock()
  local all = a_board()
  local under_review = check.must(item.decode({id = WORK, title = "a slice",
        parent = UNDER, claim = "session-a", pr = 42,
        reviewer = "reviewer-b"}))
  local lines = show.show_report(under_review, all, board_ranks(all), "", {}, {})
  assert(matched(lines, "^reviewer: reviewer%-b$"),
    "the review lock is a fact worth reading: " .. table.concat(lines, "\n"))
end

local function test_show_names_an_items_own_graph_problem()
  local all = a_board()
  local adrift = all[4]
  adrift.parent = next_id()
  local index_problems = {("parent %s does not exist"):format(adrift.parent)}
  local lines, verdict = show.show_report(adrift, all, board_ranks(all), "", {}, index_problems)
  assert(matched(lines, "bar: parent .* does not exist"),
    "a broken chain says so where it is read: "
    .. table.concat(lines, "\n"))
  assert(verdict:find("is todo", 1, true), verdict)
end

-- `blocked by` means what `flow.is_blocked` means: an edge whose
-- blocker has ended does not hold the item up, and printing it beside
-- the ones that do reads as a chain far deeper than it is. The closed
-- edges stay visible under their own heading — they are the record of
-- what the item waited on — and an item every blocker of which has
-- ended prints no `blocked by` line at all.
local function test_show_separates_binding_blockers_from_cleared_ones()
  local all = a_board()
  local open_blocker = next_id()
  local ended_blocker = next_id()
  all[#all + 1] = check.must(item.decode({id = open_blocker,
        title = "still open", parent = UNDER}))
  all[#all + 1] = check.must(item.decode({id = ended_blocker,
        title = "landed already", parent = UNDER, resolution = "completed"}))
  local waiting = check.must(item.decode({id = next_id(),
        title = "waits on one of them", parent = UNDER,
        blocked_by = open_blocker .. " " .. ended_blocker}))
  all[#all + 1] = waiting
  local lines = show.show_report(waiting, all, board_ranks(all), "", {}, {})
  assert(matched(lines, "^blocked by: " .. open_blocker .. "$"),
    "only the open blocker binds: " .. table.concat(lines, "\n"))
  assert(matched(lines, "^blockers cleared: " .. ended_blocker .. "$"),
    "the ended edge is still the record: " .. table.concat(lines, "\n"))

  local settled = check.must(item.decode({id = next_id(),
        title = "waits on nothing open", parent = UNDER,
        blocked_by = ended_blocker}))
  all[#all + 1] = settled
  local settled_lines = show.show_report(settled, all, board_ranks(all), "", {}, {})
  assert(not matched(settled_lines, "^blocked by:"),
    "nothing open holds it up: " .. table.concat(settled_lines, "\n"))
  assert(matched(settled_lines, "^blockers cleared: " .. ended_blocker .. "$"),
    "and the edge is still shown: " .. table.concat(settled_lines, "\n"))
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
  local lines = show.show_report(flagged, all, board_ranks(all), "", {}, {})
  assert(matched(lines, "^flagged: title must be one line"),
    table.concat(lines, "\n"))

  local clean = show.show_report(all[4], all, board_ranks(all), "", {}, {})
  assert(not matched(clean, "^flagged:"), "no problems, no flagged lines")
end

local function test_show_says_whether_the_spec_moved_since_the_verdict()
  local all = a_board()
  local judged = spec.revision(SIDECAR)
  local reworked = check.must(item.decode({id = WORK, title = "a slice",
        parent = UNDER, claim = "session-a", pr = 42,
        verdict = "request changes", verdict_head = "5364cc21",
        verdict_spec = judged}))
  local moved = show.show_report(reworked, all, board_ranks(all), SIDECAR .. "\n## Evidence\n",
    {}, {})
  assert(matched(moved, "^verdict: request changes %(head 5364cc21, "
      .. "spec changed since%)$"), table.concat(moved, "\n"))
  local still = show.show_report(reworked, all, board_ranks(all), SIDECAR, {}, {})
  assert(matched(still, "^verdict: request changes %(head 5364cc21, "
      .. "spec unchanged since%)$"), table.concat(still, "\n"))
  -- An unrecorded revision says nothing rather than guessing: the line
  -- reads exactly as it did before the field existed.
  local legacy = check.must(item.decode({id = WORK, title = "a slice",
        parent = UNDER, claim = "session-a", pr = 42, verdict = "accept",
        verdict_head = "5364cc21"}))
  local plain = show.show_report(legacy, all, board_ranks(all), SIDECAR, {}, {})
  assert(matched(plain, "^verdict: accept %(head 5364cc21%)$"),
    table.concat(plain, "\n"))
end

-- A research handover's deliverable is the spec at a revision, so
-- `show` prints that digest's seven hex where a diff's PR number goes,
-- and no PR line — the two never both stand.
local function test_show_prints_a_research_handovers_digest()
  local all = a_board()
  local handed = check.must(item.decode({id = next_id(), title = "a handover",
        parent = UNDER, claim = "session-a", builders = "session-a",
        result = ("abcdef0123456789"):rep(4)}))
  all[#all + 1] = handed
  local lines = show.show_report(handed, all, board_ranks(all), "## Change\ndo it\n", {}, {})
  assert(matched(lines, "^state: review$"), table.concat(lines, "\n"))
  assert(matched(lines, "^result: abcdef0$"),
    "the digest prints where a PR would: " .. table.concat(lines, "\n"))
  assert(not matched(lines, "^pr:"),
    "and no PR line stands beside it: " .. table.concat(lines, "\n"))
end

-- A handover's verdict carries no head — `verdict` leaves it "" for a
-- PR-less item — so the verdict line cites the recorded digest where
-- a diff's verdict line cites the head it judged.
local function test_show_prints_a_handovers_verdict_by_result_not_head()
  local all = a_board()
  local judged = spec.revision(SIDECAR)
  local accepted = check.must(item.decode({id = next_id(), title = "a handover",
        parent = UNDER, claim = "session-a", builders = "session-a",
        result = ("abcdef0123456789"):rep(4), verdict = "accept",
        verdict_head = "", verdict_spec = judged}))
  local lines = show.show_report(accepted, all, board_ranks(all), SIDECAR, {}, {})
  assert(matched(lines,
      "^verdict: accept %(result abcdef0, spec unchanged since%)$"),
    "the digest prints where a diff's head would: "
    .. table.concat(lines, "\n"))
end

-- `show ID` prints one `rank:` line from `_work.rank.describe` — a
-- ranked child names its position and its parent's handle, an
-- unranked one (its parent's list skips it) reads "unranked", and a
-- root reads its position among roots.
local function test_show_prints_the_rank_line_for_a_ranked_child()
  local all = a_board()
  all[1].order = {UNDER, ADRIFT}
  local ranks = rank.positions(all, {ROOT})
  local lines = show.show_report(all[2], all, ranks, "", {}, {})
  assert(matched(lines, "^rank: 1 of 2 under .+$"), table.concat(lines, "\n"))
end

local function test_show_prints_unranked_for_a_child_missing_from_the_order()
  local all = a_board()
  all[1].order = {ADRIFT}
  local ranks = rank.positions(all, {ROOT})
  local lines = show.show_report(all[2], all, ranks, "", {}, {})
  assert(matched(lines, "^rank: unranked$"), table.concat(lines, "\n"))
end

local function test_show_prints_the_rank_line_for_a_root()
  local all = a_board()
  local ranks = rank.positions(all, {ROOT, BEATEN})
  local lines = show.show_report(all[1], all, ranks, "", {}, {})
  assert(matched(lines, "^rank: root 1 of 2$"), table.concat(lines, "\n"))
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
-- already covers every open sibling — never a standalone `cat-file -p
-- <ref>:spec.md` — so it renders correctly even with that single-file
-- path (`gitread.read_spec`) stubbed to fail outright.
local function test_show_id_renders_the_spec_without_gitreads_single_file_read()
  local s = init_state_repo("show-spec-from-batch")
  local id = file_item(s, "an item", "")
  give_spec(s, id)

  local real_read_spec = gitread.read_spec
  gitread.read_spec = function(_root: string, _candidates: {string}): string
    error("gitread.read_spec must not run: the body should come from "
      .. "the batched read_specs", 0)
  end
  local ok, code, out = pcall(show_and_capture, s, id)
  gitread.read_spec = real_read_spec
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
