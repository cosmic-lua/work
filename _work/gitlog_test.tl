#!/usr/bin/env cosmic
-- The history reader and the `log ID` verb: what an item's own commits
-- carry, and what a session reads when it asks for them. The prose an
-- entry shows is the retrospective record, so the words are the
-- contract — asserted on the pure report and on the reader over a real
-- board, not on captured stdout alone.

local check = require("cosmic.check")
local child = require("cosmic.child")
local env = require("cosmic.env")
local fixture = require("_work.fixture")
local fs = require("cosmic.fs")
local gitboard = require("_work.gitboard")
local gitlog = require("_work.gitlog")
local gitreadlog = require("_work.gitreadlog")
local item = require("_work.item")
local store = require("_work.store")
local storewrite = require("_work.storewrite")
local tail = require("_work.tail")

local type Entry = gitreadlog.Entry

local init_state_repo = fixture.init_state_repo
local tmpdir = fixture.tmpdir

--- Run gitboard.main(...) and capture exactly what it prints.
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

--- Record one more commit on `id`'s ref, message verbatim — the exact
--- shape a mutation writes: a subject line, and whatever body the verb
--- put under it. `_work.gitwrite` appends its own `Op:` trailer, so
--- this also pins that the reader sees the body WITHOUT it.
--- @param s store.Store The store
--- @param id string The item to move
--- @param op string The `Op:` trailer's verb
--- @param message string Subject, and body under a blank line
--- @param apply function(item.Item) The field change the commit records
local function record(s: store.Store, id: string, op: string, message: string,
    apply: function(item.Item))
  local it = check.must(store.load(s, id))
  apply(it)
  storewrite.set_op(s, op)
  assert(storewrite.save(s, it, message))
end

--- The field change a handover records: the exact product commit.
--- @param it item.Item The item
local function hand_over(it: item.Item)
  it.claim = "session-a"
  it.handover_head = ("b"):rep(40)
end

-- The board writes no prose today: every commit's body is nothing but
-- gitboard's own trailers, so every entry reads as its subject alone.
local function test_read_history_is_oldest_first_and_bodyless_today()
  local s = init_state_repo("log-oldest")
  local _root, leaf = fixture.root_with_leaf(s)
  fixture.give_spec(s, leaf)
  local entries = check.must(gitreadlog.read_history(s.root,
      {"refs/heads/items/" .. leaf}))
  assert(#entries == 2, ("new then spec: %d"):format(#entries))
  assert(entries[1].subject == ("new %s a workable slice"):format(leaf:sub(1, 8)),
    entries[1].subject)
  assert(entries[2].subject == ("spec %s"):format(leaf:sub(1, 8)),
    entries[2].subject)
  assert(entries[1].at > 0 and entries[2].at >= entries[1].at,
    "committer dates are epoch seconds, oldest first")
  assert(#entries[1].sha == 40, "the full id: " .. entries[1].sha)
  assert(entries[1].author:match("^.+ <.+>$") ~= nil, entries[1].author)
  for _, e in ipairs(entries) do
    assert(e.body == "", ("no prose on the board today: %q"):format(e.body))
  end
end

-- A body a mutation wrote comes back whole, its own blank lines
-- included, with the tool's trailer gone.
local function test_read_history_reads_the_body_a_mutation_wrote()
  local s = init_state_repo("log-body")
  local _root, leaf = fixture.root_with_leaf(s)
  local prose = "measured 3x on the json path\n\nthe second paragraph"
  record(s, leaf, "take",
    ("take %s by session-a head:%s\n\n%s"):format(leaf:sub(1, 8),
      ("b"):rep(12), prose), hand_over)
  local entries = check.must(gitreadlog.read_history(s.root,
      {"refs/heads/items/" .. leaf}))
  local last = entries[#entries]
  assert(last.body == prose, ("the prose, trailer dropped: %q"):format(last.body))
end

-- Only the tool's own trailer paragraphs are dropped; a prose line that
-- merely looks like one survives.
local function test_prose_of_drops_only_gitboards_own_trailers()
  assert(gitreadlog.prose_of("Op: take\n") == "", "the bare Op trailer")
  assert(gitreadlog.prose_of(
      "Claim-Batch: abc\n\nOp: claim-bridge\n") == "",
    "a claim bridge carries two trailer paragraphs and no prose")
  assert(gitreadlog.prose_of("measured 3x\n\nOp: take\n") == "measured 3x",
    "prose above the trailer")
  assert(gitreadlog.prose_of("Note: keep this\n\nOp: take\n") == "Note: keep this",
    "an unknown key is prose, not a trailer")
  assert(gitreadlog.prose_of("") == "", "an empty body")
end

-- The whole-board form costs ONE git process however many items it
-- reads, and attributes every commit to the item whose ref carried it.
local function test_read_histories_is_one_process_for_every_item()
  local s = init_state_repo("log-batch")
  local _root, leaf = fixture.root_with_leaf(s)
  local peers = check.must(store.list(s))
  local ids: {string} = {}
  local shas_by_id: {string: string} = {}
  -- The board's own first commit is subjectless of any id (`board`),
  -- so the per-item attribution below reads the items under it.
  for _, it in ipairs(peers) do
    if it.parent ~= "" then
      ids[#ids + 1] = it.id
      shas_by_id[it.id] = s.leased_sha[it.id]
    end
  end
  assert(#ids == 3, ("two outcomes and the leaf: %d"):format(#ids))
  local real_git = check.must(child.run({"sh", "-c", "command -v git"})).stdout
  real_git = (real_git:gsub("%s+$", ""))
  local wrapdir = fs.join(tmpdir, "gitlog-git-wrap")
  assert(fs.remove_all(wrapdir))
  assert(fs.make_dirs(wrapdir))
  local counter = fs.join(tmpdir, "gitlog-git-count.txt")
  assert(fs.write(counter, ""))
  assert(fs.write(fs.join(wrapdir, "git"),
      ("#!/bin/sh\nprintf x >> '%s'\nexec '%s' \"$@\"\n"):format(counter, real_git)))
  assert(fs.set_mode(fs.join(wrapdir, "git"), fs.octal("755")))
  local old_path = os.getenv("PATH") or ""
  assert(env.set("PATH", wrapdir .. ":" .. old_path, true))
  local by_id = check.must(gitreadlog.read_histories(s.root, shas_by_id, ids))
  assert(env.set("PATH", old_path, true))
  assert(#(fs.read(counter) or "") == 1,
    ("one process for the whole board: %d"):format(#(fs.read(counter) or "")))
  local leaf_entries = by_id[leaf]
  assert(#leaf_entries == 1, ("the leaf's own new: %d"):format(#leaf_entries))
  assert(leaf_entries[1].subject
    == ("new %s a workable slice"):format(leaf:sub(1, 8)),
    leaf_entries[1].subject)
  -- One merged walk must attribute each commit to the ref it sits on,
  -- which the per-ref reader answers independently: the two agree, id
  -- by id and commit by commit.
  for _, id in ipairs(ids) do
    local own = by_id[id]
    local alone = check.must(gitreadlog.read_history(s.root,
        {"refs/heads/items/" .. id}))
    assert(#own == #alone,
      ("%s: %d batched vs %d alone"):format(id:sub(1, 8), #own, #alone))
    for i, e in ipairs(alone) do
      assert(own[i].sha == e.sha,
        ("%s entry %d: %s vs %s"):format(id:sub(1, 8), i, own[i].sha, e.sha))
    end
  end
end

--- Synthetic entries, oldest first, for the pure selections below.
--- @return {Entry}
local function a_history(): {Entry}
  return {
    {sha = ("1"):rep(40), at = 100, author = "a <a@board>",
      subject = "new abcd1234 a slice", body = ""},
    {sha = ("2"):rep(40), at = 200, author = "a <a@board>",
      subject = "take abcd1234 by session-a", body = "the claim's own note"},
    {sha = ("3"):rep(40), at = 300, author = "a <a@board>",
      subject = "take abcd1234 by session-a head:bbbbbbbbbbbb",
      body = "what the build found"},
    {sha = ("4"):rep(40), at = 400, author = "b <b@board>",
      subject = "done abcd1234 completed (from accepted)",
      body = "what came of it"},
  }
end

-- The resolution's own commit is the outcome once an item is resolved;
-- while it is open, the latest handover is — and a bare claim take,
-- which carries no head, is neither.
local function test_outcome_body_picks_the_resolution_then_the_handover()
  local entries = a_history()
  assert(gitreadlog.outcome_body(entries, true) == "what came of it",
    "the done commit")
  assert(gitreadlog.outcome_body(entries, false) == "what the build found",
    "the handover commit while open")
  -- The bare claim take carries prose of its own, so a selector that
  -- matched every `take` would return it: only ` head:`/` result:`
  -- names a handover.
  local unhanded: {Entry} = {entries[1], entries[2]}
  assert(gitreadlog.outcome_body(unhanded, false) == "",
    "a bare claim take is not a handover")
  assert(gitreadlog.outcome_body({}, true) == "", "no commits, no outcome")
end

-- The render: newest first, one heading per entry, the body indented
-- under its own heading.
local function test_log_report_renders_newest_first_with_indented_bodies()
  local lines = gitlog.log_report(a_history())
  assert(lines[1]:find("done abcd1234 completed", 1, true) ~= nil,
    "newest first: " .. lines[1])
  assert(lines[1]:match("^1970%-01%-01T00:06:40Z b <b@board> ") ~= nil,
    "date, author, subject: " .. lines[1])
  assert(lines[2] == "    what came of it", "the body, indented: " .. lines[2])
  assert(lines[3]:find("head:bbbbbbbbbbbb", 1, true) ~= nil,
    "then the handover: " .. lines[3])
  assert(lines[4] == "    what the build found", lines[4])
  assert(lines[5]:find("take abcd1234 by session-a", 1, true) ~= nil
    and lines[5]:find("head:", 1, true) == nil, lines[5])
  assert(lines[6] == "    the claim's own note", lines[6])
  assert(lines[7]:find("new abcd1234", 1, true) ~= nil,
    "an empty body prints its subject alone: " .. lines[7])
  assert(#lines == 7, ("four entries, three bodies: %d"):format(#lines))
end

-- `--oneline` keeps every heading and drops every body.
local function test_log_report_oneline_drops_every_body()
  local lines = gitlog.log_report(a_history(), true)
  assert(#lines == 4, ("one line per entry: %d"):format(#lines))
  for _, line in ipairs(lines) do
    assert(line:match("^%d%d%d%d%-") ~= nil, "each is a heading: " .. line)
  end
end

-- A blank line inside a body stays blank rather than becoming indented
-- whitespace, so a paragraph break survives the render.
local function test_log_report_keeps_a_blank_line_blank()
  local lines = gitlog.log_report({
      {sha = ("1"):rep(40), at = 100, author = "a <a@board>",
        subject = "spec abcd1234", body = "first\n\nsecond"},
    })
  assert(lines[2] == "    first", lines[2])
  assert(lines[3] == "", ("a blank line, not indentation: %q"):format(lines[3]))
  assert(lines[4] == "    second", lines[4])
end

-- The verb end to end, by handle, through the dispatcher.
local function test_log_verb_prints_an_items_history()
  local s = init_state_repo("log-verb")
  local _root, leaf = fixture.root_with_leaf(s)
  record(s, leaf, "take",
    ("take %s by session-a head:%s\n\nwhat the build found"):format(
      leaf:sub(1, 8), ("b"):rep(12)), hand_over)
  assert(store.close(s))
  local code, printed = gitboard_and_capture("log", tail.handle(leaf),
    "--dir", s.root)
  assert(code == 0, printed)
  assert(printed:find("what the build found", 1, true) ~= nil,
    "the body is why the verb exists: " .. printed)
  assert(printed:find("Op: take", 1, true) == nil,
    "the tool's trailer is not prose: " .. printed)
  assert(printed:find("gitboard-log: " .. tail.handle(leaf) .. " carries 2 entries",
      1, true) ~= nil, "the verdict line counts them: " .. printed)

  local oneline_code, oneline = gitboard_and_capture("log", tail.handle(leaf),
    "--oneline", "--dir", s.root)
  assert(oneline_code == 0, oneline)
  assert(oneline:find("what the build found", 1, true) == nil,
    "--oneline drops bodies: " .. oneline)
  assert(oneline:find("head:bbbbbbbbbbbb", 1, true) ~= nil,
    "and keeps subjects: " .. oneline)
end
