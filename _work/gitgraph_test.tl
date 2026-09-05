#!/usr/bin/env cosmic
-- The graph verbs against scratch state repositories: filing an item,
-- the parent edge, its refusals, and the properties that hold across
-- such a mutation — one commit per change, and locks that cannot
-- outlive the decomposition that made their holder a container.

local check = require("cosmic.check")
local flow = require("_work.flow")
local gitboard = require("_work.gitboard")
local publish = require("_work.publish")
local read = require("_work.read")
local store = require("_work.store")
local fixture = require("_work.fixture")
local graph = require("_work.gitgraph")
local verbs = require("_work.gitverbs")

local init_state_repo = fixture.init_state_repo
local file_item = fixture.file_item
local commits = fixture.commits
local give_spec = fixture.give_spec
local root_with_leaf = fixture.root_with_leaf

local function test_decomposition_is_one_push_two_commits()
  local s = init_state_repo("decompose")
  local _, leaf = root_with_leaf(s)
  -- The leaf is mid-build when the child arrives: the decomposition
  -- clears the lock — the child's OWN commit and the lock-clearing
  -- commit on the parent, landed together in one atomic push.
  give_spec(s, leaf)
  assert(verbs.cmd_take(s, leaf, "session-A", 0, false, "") == 0)
  local before = commits(s)
  local _kid = file_item(s, "a sub-slice", leaf)
  assert(commits(s) == before + 2,
    ("one push, two commits — child and de-phased parent: %d -> %d")
    :format(before, commits(s)))
  local parent = check.must(store.load(s, leaf))
  assert(parent.claim == "",
    "gaining a child clears the lock on the new container")
end

-- `new --repo` scopes the item's PR to a foreign repo; the field is
-- what makes cross-repo work (a cosmopolitan fix serving a cosmic
-- goal) visible instead of a URL buried in prose.
local function test_new_repo_lands_the_field()
  local s = init_state_repo("cross-repo")
  local goal = file_item(s, "an outcome", "")
  local before: {string: boolean} = {}
  for _, i in ipairs(check.must(store.list(s))) do
    before[i.id] = true
  end
  assert(graph.cmd_new(s, "a cosmopolitan-side slice", goal, nil,
      "whilp/cosmopolitan") == 0)
  local found: string = nil
  for _, i in ipairs(check.must(store.list(s))) do
    if not before[i.id] then
      found = i.id
    end
  end
  assert(found ~= nil, "the new item is on the board")
  local it = check.must(store.load(s, found))
  assert(it.repo == "whilp/cosmopolitan",
    "the field lands on the stored item: " .. it.repo)
end

-- A title carrying a newline lands in the item file and `show` then
-- renders the second line as its own board row, indistinguishable
-- from a real item — the shape check lives in `item.problems`, the
-- one place both `new` and `set --title` route their finished item
-- through, so this refusal is the same one `set` gets below.
local function test_new_refuses_a_multiline_or_padded_title()
  local s = init_state_repo("new-hostile-title")
  local before = check.must(store.list(s))
  assert(graph.cmd_new(s, "innocent\nfake line", "", nil, "") ~= 0,
    "a newline in the title is refused")
  assert(graph.cmd_new(s, "  padded  ", "", nil, "") ~= 0,
    "leading/trailing whitespace in the title is refused")
  local after = check.must(store.list(s))
  assert(#after == #before, "neither refusal filed an item")
end

-- Filing and adoption are never refused: todo is unbounded by design
-- — the queue intake writes into can always accept — and the doing
-- bound binds at take, where committing to work is the expensive
-- decision. A board at the bound still files and still adopts.
local function test_filing_is_admitted_at_the_doing_bound()
  local s = init_state_repo("bound")
  local goal, leaf = root_with_leaf(s)
  for k = 1, flow.DOING_LIMIT do
    local id = file_item(s, ("in flight %d"):format(k), goal)
    give_spec(s, id)
    assert(verbs.cmd_take(s, id, ("wake-%d"):format(k), 0, false, "") == 0,
      "the bound admits takes up to its number")
  end
  check.must(store.list(s))
  local c = check.must(store.read(s))
  assert(check.must(read.doing_count(c)) >= flow.DOING_LIMIT,
    "the board is at the bound")
  local capture = file_item(s, "a capture", "")
  assert(graph.cmd_attach(s, capture, goal) == 0,
    "adoption is admitted at the bound")
  give_spec(s, leaf)
  assert(verbs.cmd_take(s, leaf, "one-more", 0, false, "") ~= 0,
    "and the take is what the bound refuses")
end

-- `set` repairs the three destination facts a refinement can outgrow:
-- title, repo, base. Each round-trips through a real store, and the
-- commit subject names WHICH fields moved, never their values.
local function test_set_round_trips_title_repo_and_base()
  local s = init_state_repo("set-round-trip")
  local goal, leaf = root_with_leaf(s)
  assert(graph.cmd_set(s, leaf, "a truer title", "whilp/cosmopolitan",
      "release") == 0)
  local it = check.must(store.load(s, leaf))
  assert(it.title == "a truer title", "title landed: " .. it.title)
  assert(it.repo == "whilp/cosmopolitan", "repo landed: " .. it.repo)
  assert(it.base == "release", "base landed: " .. it.base)
  local events = check.must(publish.history(s, leaf))
  assert(events[1].subject:match("^set %w%w%w%w%w%w%w%w title repo base$")
    ~= nil, "the subject names the fields, canonically ordered, no "
    .. "values: " .. events[1].subject)
  assert(not events[1].subject:find("a truer title", 1, true),
    "the title text stays out of the subject: " .. events[1].subject)

  -- Setting only one field leaves the others untouched.
  assert(graph.cmd_set(s, leaf, nil, nil, "main") == 0)
  local moved = check.must(store.load(s, leaf))
  assert(moved.base == "main" and moved.title == "a truer title"
    and moved.repo == "whilp/cosmopolitan",
    "an unset flag leaves its field alone")
  assert(goal ~= "", "root filed for the fixture")
end

-- The already-recorded case: setting a field to the value it already
-- holds asks for the state the board already has — a no-op that
-- succeeds, not a refusal, printing `store`'s own no-op line.
local function test_set_the_same_value_is_a_noop_success()
  local s = init_state_repo("set-noop")
  local _, leaf = root_with_leaf(s)
  assert(graph.cmd_set(s, leaf, "a truer title", nil, nil) == 0)
  local before = commits(s)
  local old_print = _G.print
  local lines: {string} = {}
  _G.print = function(...: any)
    local parts: {string} = {}
    for i = 1, select("#", ...) do
      parts[i] = tostring((select(i, ...)))
    end
    lines[#lines + 1] = table.concat(parts, "\t")
  end
  local code = graph.cmd_set(s, leaf, "a truer title", nil, nil)
  _G.print = old_print
  assert(code == 0, "the same title again is a no-op, not a refusal")
  assert(table.concat(lines, "\n"):find("nothing to record", 1, true) ~= nil,
    "prints store's own no-op line: " .. table.concat(lines, "\n"))
  assert(commits(s) == before, "a no-op writes no commit")
end

-- No flags at all names nothing to repair.
local function test_set_with_no_flags_is_refused()
  local s = init_state_repo("set-empty")
  local _, leaf = root_with_leaf(s)
  assert(graph.cmd_set(s, leaf, nil, nil, nil) ~= 0,
    "set needs at least one field")
end

-- An explicit empty --repo/--base would silently CLEAR the field —
-- an un-gating path (an empty base means "ungated") with no flag
-- naming what it just did. Refuse it instead; the way to change the
-- field stays `set --repo/--base <value>`.
local function test_set_refuses_an_empty_repo_or_base()
  local s = init_state_repo("set-empty-clear")
  local _, leaf = root_with_leaf(s)
  assert(graph.cmd_set(s, leaf, "a truer title", "whilp/cosmopolitan",
      "release") == 0)
  assert(graph.cmd_set(s, leaf, nil, "", nil) ~= 0,
    "an empty --repo is refused, not treated as a clear")
  assert(graph.cmd_set(s, leaf, nil, nil, "") ~= 0,
    "an empty --base is refused, not treated as a clear")
  local it = check.must(store.load(s, leaf))
  assert(it.repo == "whilp/cosmopolitan" and it.base == "release",
    "neither refusal cleared the field")
end

-- `set --title` is the other entry point that writes a title; the
-- same shape check refuses it there, and nothing gets overwritten.
local function test_set_refuses_a_multiline_or_padded_title()
  local s = init_state_repo("set-hostile-title")
  local _, leaf = root_with_leaf(s)
  local before = check.must(store.load(s, leaf))
  assert(graph.cmd_set(s, leaf, "innocent\nfake line", nil, nil) ~= 0,
    "a newline in the title is refused")
  assert(graph.cmd_set(s, leaf, "  padded  ", nil, nil) ~= 0,
    "leading/trailing whitespace in the title is refused")
  local after = check.must(store.load(s, leaf))
  assert(after.title == before.title,
    "neither refusal changed the stored title")
end

-- A finished item's destination facts are history, not a repair
-- target.
local function test_set_refuses_a_done_item()
  local s = init_state_repo("set-done")
  local _, leaf = root_with_leaf(s)
  assert(verbs.cmd_done(s, leaf, "not-planned", false, "") == 0)
  assert(graph.cmd_set(s, leaf, "a new title", nil, nil) ~= 0,
    "a done item refuses set")
  local it = check.must(store.load(s, leaf))
  assert(it.title ~= "a new title", "and nothing was written")
end

-- `set` declares only title/repo/base — every flow field (claim, pr,
-- verdict, resolution, parent, lane) has its own verb and
-- gate, so `set` refuses those by not declaring the flag at all: the
-- dispatcher's own unrecognized-flag error, before `cmd_set` runs.
local function test_set_refuses_an_unknown_flag()
  local s = init_state_repo("set-unknown-flag")
  local _, leaf = root_with_leaf(s)
  assert(gitboard.main("set", leaf, "--claim", "session-x",
      "--dir", s.root) ~= 0,
    "a flow field is not a set flag")
  local it = check.must(store.load(s, leaf))
  assert(it.claim == "", "nothing was written")
end

-- The wall by name: EVERY flow field — not just --claim — has its own
-- verb and gate, and `set` must refuse each as an unrecognized flag
-- rather than reach `cmd_set`'s body, which has no field to write it
-- into. Driven through the full CLI dispatch (not `graph.cmd_set`
-- directly) because the wall lives in the flag SPEC `set` declares,
-- not in `cmd_set`'s own logic. A test that only checks the exit code
-- of `--claim` alone cannot tell the dispatcher's unknown-flag
-- refusal from cmd_set's unrelated "needs at least one of --title,
-- --repo, --base" refusal — both exit nonzero — so this checks the
-- item file is untouched after every attempt too: a flag that got
-- wired AND written would leave a trace here even if some other path
-- also happened to exit nonzero.
local function test_set_refuses_every_flow_field_flag()
  local s = init_state_repo("set-flow-wall")
  local _, leaf = root_with_leaf(s)
  local before = check.must(store.load(s, leaf))
  local flow_flags: {{string, string}} = {
    {"--claim", "session-x"},
    {"--pr", "5"},
    {"--verdict", "accept"},
    {"--parent", leaf},
    {"--resolution", "completed"},
    {"--key", "release.yml"},
  }
  for _, pair in ipairs(flow_flags) do
    local flag, value = pair[1], pair[2]
    assert(gitboard.main("set", leaf, flag, value, "--dir", s.root) ~= 0,
      flag .. " is a flow field, not a set flag")
  end
  local after = check.must(store.load(s, leaf))
  assert(after.claim == before.claim, "claim untouched: " .. after.claim)
  assert(after.pr == before.pr, "pr untouched: " .. tostring(after.pr))
  assert(after.verdict == before.verdict, "verdict untouched: " .. after.verdict)
  assert(after.parent == before.parent, "parent untouched: " .. after.parent)
  assert(after.resolution == before.resolution,
    "resolution untouched: " .. after.resolution)
  assert(after.key == before.key, "key untouched: " .. after.key)
end
