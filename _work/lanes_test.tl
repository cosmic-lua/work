#!/usr/bin/env cosmic
-- Lane health as board state: mint's idempotency and auto-close
-- guards, record's change-gated write to the cache's `lanes` table,
-- and observe's offline path. The network call itself (`observe_one`'s
-- GET) is exercised only live, against a real GitHub token; these
-- tests drive `record` and `mint` with a fake facts table, the way
-- `cmd_sync` would after a real `observe` returned one.

local check = require("cosmic.check")
local env = require("cosmic.env")
local action = require("_work.action")
local api = require("_work.api")
local cache = require("_work.cache")
local fixture = require("_work.fixture")
local flow = require("_work.flow")
local fs = require("cosmic.fs")
local gitready = require("_work.gitready")
local gitobj = require("_work.gitobj")
local gitrank = require("_work.gitrank")
local item = require("_work.item")
local lanes = require("_work.lanes")
local refs = require("_work.refs")
local spec = require("_work.spec")
local store = require("_work.store")
local storewrite = require("_work.storewrite")

local init_state_repo = fixture.init_state_repo

local RED: {string: string} = {["release.yml"] = "failure",
  ["fuzz.yml"] = "success", ["docs.yml"] = "success"}
local GREEN: {string: string} = {["release.yml"] = "success",
  ["fuzz.yml"] = "success", ["docs.yml"] = "success"}

--- The one open repair item carrying `lane` as its `key`, nil when
--- there is none.
local function repair_for(all: {item.Item}, lane: string): item.Item
  for _, it in ipairs(all) do
    if item.is_open(it) and it.key == lane then
      return it
    end
  end
  return nil
end

-- Two red observations of the same lane mint exactly one repair item:
-- the lane's filename is the idempotency key `mint` searches on
-- before ever filing one — five red days cost one item, not five.
local function test_mint_is_idempotent_per_lane()
  local s = init_state_repo("mint-idempotent")
  assert(lanes.mint(s, RED))
  local repair = repair_for(check.must(store.list(s)), "release.yml")
  assert(repair ~= nil, "one repair item filed for the red lane")

  -- The minted sidecar clears the spec bar honestly — `_work.spec`'s
  -- real check, not a copy of its rule — which is what lets `next`
  -- offer the item and `take` admit it without disagreeing.
  local body = store.read_spec(s, repair.id)
  local gaps = spec.ready_gaps(body)
  assert(#gaps == 0,
    "the minted sidecar passes the spec bar: " .. table.concat(gaps, "; "))

  assert(lanes.mint(s, RED))
  local all = check.must(store.list(s))
  local count = 0
  for _, it in ipairs(all) do
    if it.key == "release.yml" then count = count + 1 end
  end
  assert(count == 1,
    "a second red observation mints nothing new: " .. tostring(count))
end

-- A lane back to green closes its UNCLAIMED repair item, as
-- not-planned — the monitor observed a fact, it never completed work.
local function test_green_closes_an_unclaimed_repair()
  local s = init_state_repo("mint-closes")
  assert(lanes.mint(s, RED))
  local repair = repair_for(check.must(store.list(s)), "release.yml")
  assert(repair ~= nil and item.is_open(repair), "the repair starts open")

  assert(lanes.mint(s, GREEN))
  local closed = check.must(store.load(s, repair.id))
  assert(not item.is_open(closed), "the green lane closes its repair")
  assert(closed.resolution == "not-planned",
    "auto-closed as not-planned, never completed: " .. closed.resolution)
end

-- A CLAIMED repair is left alone even when its lane goes green: the
-- monitor never undoes a builder's in-flight claim.
local function test_a_claimed_repair_is_left_alone_on_green()
  local s = init_state_repo("mint-claimed")
  assert(lanes.mint(s, RED))
  local repair = repair_for(check.must(store.list(s)), "release.yml")
  assert(repair ~= nil)
  repair.claim = "session-a"
  assert(storewrite.save(s, repair, ("take %s by session-a"):format(
        repair.id:sub(1, 8))))

  assert(lanes.mint(s, GREEN))
  local still = check.must(store.load(s, repair.id))
  assert(item.is_open(still), "a claimed repair stays open on green")
  assert(still.claim == "session-a", "and the claim is untouched")
end

-- record writes ONLY when the facts changed from what is already
-- recorded; a re-observation that agrees with the last one writes
-- nothing, so the cache records a fact CHANGING, not a fact being
-- re-confirmed every sync.
local function test_record_writes_only_on_change()
  local s = init_state_repo("record-change")
  local facts: {string: string} = {["release.yml"] = "success",
    ["fuzz.yml"] = "success", ["docs.yml"] = "success"}
  assert(lanes.record(s, facts), "the first observation is new, and writes")
  assert(lanes.read_state(s)["fuzz.yml"] == "success")

  local ok, err = lanes.record(s, facts)
  assert(not ok, "an unchanged observation records nothing")
  assert(err == "", "and carries no error — this is a no-op, not a failure")

  facts["fuzz.yml"] = "failure"
  assert(lanes.record(s, facts), "a real change writes again")
  assert(lanes.read_state(s)["fuzz.yml"] == "failure")
end

-- Every board mutation commits under the bot identity, not the host's
-- ambient git config or a name GitHub renders "Unverified" —
-- `store.tl`'s shared GIT_DEFAULTS. A lane sync no longer commits at
-- all (it writes the cache's local `lanes` table), so this now checks
-- only the one call site left that does.
local function test_board_commits_carry_the_claude_identity()
  local s = init_state_repo("identity")
  fixture.file_item(s, "an outcome", "")
  assert(fixture.commit_author_email(s) == "noreply@anthropic.com",
    "item mutation author: " .. fixture.commit_author_email(s))
end

-- `report` is what `cmd_sync` calls (via `at_sync`) after a real
-- `observe` returns facts; a `record` failure must show up in its
-- lines rather than vanish the way `cmd_sync` used to discard it.
-- Forced the same way `_work/cache_test.tl` forces a rebuild failure:
-- a plain FILE sits where the cache's `o/` directory needs to be, so
-- `rebuild`'s own `make_dirs` refuses it structurally.
local function test_report_surfaces_a_record_failure()
  local s = init_state_repo("report-record-fails")
  assert(fs.write(fs.join(s.root, "o"), "blocker"))
  local lines = lanes.report(s, RED)
  local found = false
  for _, line in ipairs(lines) do
    if line:find("lanes record failed", 1, true) then found = true end
  end
  assert(found, "a record failure is printed, not discarded: "
    .. table.concat(lines, " | "))
end

-- Symmetric case: an item ref whose tip commit carries no `meta` blob
-- at all makes `mint`'s `store.list` fail (the one shape `list`
-- treats as genuine corruption, `_work/gitread.tl`'s `build_item`),
-- without touching `record`, which writes to a different ref
-- entirely. `report` must surface this one too.
local function test_report_surfaces_a_mint_failure()
  local s = init_state_repo("report-mint-fails")
  local id = fixture.file_item(s, "a corrupt item", "")
  local empty_tree = check.must(gitobj.mktree(s.root, {}))
  local bogus_sha = check.must(gitobj.commit_tree(s.root, {
        tree = empty_tree, parents = {}, message = "corrupt: no meta",
        author_name = "test", author_email = "test@example.com",
        committer_name = "test", committer_email = "test@example.com",
      }))
  assert(store.git_ok(s, {"update-ref", "refs/heads/items/" .. id, bogus_sha}))
  local lines = lanes.report(s, RED)
  local found = false
  for _, line in ipairs(lines) do
    if line:find("lanes mint failed", 1, true) then found = true end
  end
  assert(found, "a mint failure is printed, not discarded: "
    .. table.concat(lines, " | "))
end

-- observe needs a slug to address GitHub with; a checkout with no
-- origin has none, so the whole observation comes back "unknown" —
-- the same shape a token-less or offline sync sees — with no network
-- ever touched, which is what makes this safe to run in CI.
local function test_observe_with_no_origin_is_unknown_not_red()
  local s = init_state_repo("observe-no-origin")
  local facts, err = lanes.observe(s)
  assert(facts == nil, "no slug to address means no facts")
  assert(err:find("no origin remote", 1, true) ~= nil, "got: " .. err)
end

-- A minted repair is coherent with the two verbs that decide its
-- fate: `next` (`_work.action.next_action`) offers it, and `take`
-- (`_work.gitready.ready_problems` plus `flow.doing_refusal`, the exact
-- pair `cmd_take` calls) admits it. Placed the way the real repair
-- parent (G8) already is on the live board — ranked among the roots,
-- inherited by every child minted under it — so the only variable
-- under test is the sidecar `file_repair` now writes.
local function test_a_minted_repair_is_offered_and_admitted()
  local s = init_state_repo("mint-admitted")
  local board = check.must(flow.find_board(check.must(store.list(s))))
  local parent = check.must(item.decode({id = lanes.LANE_PARENT,
        title = "lane repair outcome", parent = board.id}))
  assert(storewrite.save(s, parent, "new " .. parent.id:sub(1, 8) .. " lane repairs"))
  assert(gitrank.cmd_rank(s, parent.id, "", "", true) == 0,
    "rank should be accepted")

  assert(lanes.mint(s, RED))
  local all = check.must(store.list(s))
  local repair = repair_for(all, "release.yml")
  assert(repair ~= nil, "the red lane minted a repair")

  local specs: {string: string} = {}
  for _, it in ipairs(all) do
    specs[it.id] = store.read_spec(s, it.id)
  end
  local a = action.next_action(all, specs)
  assert(a.kind == "pull" and a.item.id == repair.id,
    "next offers the minted repair: " .. a.kind
    .. " " .. (a.item and a.item.id or ""))

  local problems = gitready.ready_problems(s, repair, all)
  assert(#problems == 0,
    "take admits it too: " .. table.concat(problems, "; "))
  assert(flow.doing_refusal(all, repair) == nil,
    "and the doing bound never holds a lane repair back")
end

-- The freshness window: an observation noted moments ago skips the
-- read entirely, with one line saying so. `at_sync` never reaches
-- `observe` on this path, so a checkout with no origin (which
-- `observe` would refuse) still passes — the skip is provably before
-- any network is even considered.
local function test_at_sync_skips_within_the_freshness_window()
  local s = init_state_repo("lanes-fresh")
  lanes.touch_observed_at(s)
  local lines = lanes.at_sync(s)
  assert(#lines == 1, table.concat(lines, " | "))
  assert(lines[1]:find("skipped", 1, true) ~= nil, "got: " .. lines[1])
  assert(lines[1]:find("freshness window", 1, true) ~= nil, "got: " .. lines[1])
end

-- The env override forces past the window: with it set, `at_sync`
-- proceeds to `observe`, which fails loudly for a checkout with no
-- origin — proof the override is felt, not silently absorbed by the
-- skip it is meant to bypass.
local function test_fresh_env_forces_past_the_freshness_window()
  local s = init_state_repo("lanes-fresh-forced")
  lanes.touch_observed_at(s)
  assert(env.set(lanes.FRESH_ENV, "1"))
  local lines = lanes.at_sync(s)
  assert(env.unset(lanes.FRESH_ENV))
  assert(#lines == 1, table.concat(lines, " | "))
  assert(lines[1]:find("unknown", 1, true) ~= nil, "got: " .. lines[1])
  assert(lines[1]:find("no origin remote", 1, true) ~= nil, "got: " .. lines[1])
end

-- A quota below the floor skips the read too, with its own notice —
-- and, like the freshness skip, never reaches `observe` (no rate file
-- yet means no freshness skip first, so this proves the SECOND gate).
local function test_at_sync_skips_on_low_remaining()
  local s = init_state_repo("lanes-low-remaining")
  api.write_rate(s.root, lanes.LOW_REMAINING - 1, 1735689600)
  local lines = lanes.at_sync(s)
  assert(#lines == 1, table.concat(lines, " | "))
  assert(lines[1]:find("rate limit low", 1, true) ~= nil, "got: " .. lines[1])
end

-- A quota at or above the floor changes nothing: `at_sync` still
-- reaches `observe`, which fails loudly for a checkout with no
-- origin — the degrade only ever narrows what a healthy quota does,
-- never replaces it.
local function test_at_sync_proceeds_on_healthy_remaining()
  local s = init_state_repo("lanes-healthy-remaining")
  api.write_rate(s.root, lanes.LOW_REMAINING + 100, 1735689600)
  local lines = lanes.at_sync(s)
  assert(#lines == 1, table.concat(lines, " | "))
  assert(lines[1]:find("no origin remote", 1, true) ~= nil, "got: " .. lines[1])
end

-- `read_state` hands the cache `s.board_digest` once a `list` has set
-- one, so the digest check never retakes the ref snapshot `list`
-- already has — `_work/cache_test.tl` proves `cache.open` itself
-- honors a known digest; this proves `lanes` actually passes one.
local function test_read_state_reuses_a_known_board_digest()
  local s = init_state_repo("lanes-digest-reuse")
  check.must(cache.close(check.must(cache.open(s.root))))
  check.must(store.list(s))
  assert(s.board_digest ~= "", "list should have set a board digest")

  local calls = 0
  local real_for_each_ref = refs.for_each_ref
  refs.for_each_ref = function(root: string, patterns: {string}):
    {refs.RefEntry} | nil, string
    calls = calls + 1
    return real_for_each_ref(root, patterns)
  end
  local ok, err = pcall(lanes.read_state, s)
  refs.for_each_ref = real_for_each_ref
  if not ok then
    error(err, 0)
  end
  assert(calls == 0, "read_state must not retake the ref snapshot just "
    .. "to validate the cache: " .. calls)
end
