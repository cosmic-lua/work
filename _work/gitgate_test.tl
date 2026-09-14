#!/usr/bin/env cosmic
-- `commit_and_publish` under a lost push race: the mutation is
-- dropped whole, the checkout re-synced, and the refusal is
-- `store.LOST_RACE` — never a replay of a commit whose preconditions
-- the winner may have falsified. The re-run is the verb's, and it
-- decides afresh against the merged board — where every gate,
-- the doing bound included, is re-applied. The ready bar's owner
-- rule on an item's own `repo` is the second half of this file; the
-- write-time half of the same rule is `_work/gitowner_test.tl`.

local check = require("cosmic.check")
local fs = require("cosmic.fs")
local fixture = require("_work.fixture")
local flow = require("_work.flow")
local gate = require("_work.gitgate")
local gitdepend = require("_work.gitdepend")
local gitdone = require("_work.gitdone")
local gitready = require("_work.gitready")
local gitspec = require("_work.gitspec")
local graph = require("_work.gitgraph")
local item = require("_work.item")
local itemtree = require("_work.itemtree")
local ksuid = require("_work.ksuid")
local owner = require("_work.gitowner")
local publish = require("_work.publish")
local read = require("_work.read")
local refs = require("_work.refs")
local staging = require("_work.statestaging")
local native = require("_work.statepublish")
local store = require("_work.store")
local storewrite = require("_work.storewrite")
local tail = require("_work.tail")

local init_shared = fixture.init_shared
local init_state_repo = fixture.init_state_repo

--- The prose the mutations below carry, so the write path under test is
--- the one a real `spec`/`new` takes rather than a spec-less one.
local SPEC_TOUCH < const >: itemtree.Spec = {
  change = "a spec touch\n", non_goals = "",
}

local counter = 0

--- A fresh deterministic id; later calls sort later.
local function fresh_id(): string
  counter = counter + 1
  return check.must(ksuid.encode(1700000000 + counter, ("\0"):rep(16)))
end

local PARENT = check.must(ksuid.encode(1690000000, ("\1"):rep(16)))

--- A minimal valid workable item — under a parent the store never
--- checks, the same convention `store_test.tl` uses.
local function make_item(over?: {string: any}): item.Item
  local t: {string: any} = {
    id = fresh_id(), title = "filler", parent = PARENT,
  }
  for k, v in pairs(over or {}) do
    t[k] = v
  end
  return check.must(item.decode(t))
end

-- A lost race is a refusal, not a replay: the commit is dropped, the
-- checkout holds the winner's state, and the refusal is LOST_RACE by
-- identity.
local function test_a_lost_race_drops_the_mutation_and_refuses()
  local a, b = init_shared("gate-lost")
  local id = fixture.file_item(a, "shared race target", "")
  fixture.caller_fetch(b)
  local touched = check.must(store.load(a, id))
  touched.title = "the winner"
  storewrite.set_bounded(a, true)
  assert(storewrite.save(a, touched, "a moves the remote forward"))
  assert(publish.publish(a))
  fixture.caller_publish(a)

  local mine = check.must(store.load(b, id))
  mine.title = "the loser"
  local ok, err = gate.commit_and_publish(b, mine, SPEC_TOUCH,
    ("spec %s"):format(mine.id:sub(1, 8)), "set")
  assert(ok, "the stale mutation may be prepared locally: " .. tostring(err))
  local pending = check.must(staging.list(b.root))
  assert(#pending == 1, "the stale mutation has one durable transaction")
  local pushed, perr = native.execute(b.root, pending[1])
  assert(not pushed and perr == store.LOST_RACE,
    "the native path fence detects the lost race")
  assert(native.sync(b), "the checkout re-syncs to the winner")
  assert(check.must(store.load(b, id)).title == "the winner",
    "the checkout was re-synced and the mutation dropped whole")
end

-- The re-run is the compare-and-swap completing: the same mutation,
-- decided and committed again against the merged state, publishes.
local function test_the_rerun_publishes_against_the_merged_state()
  local a, b = init_shared("gate-rerun")
  local id = fixture.file_item(a, "shared rerun target", "")
  fixture.caller_fetch(b)
  local touched = check.must(store.load(a, id))
  touched.title = "the winner"
  storewrite.set_bounded(a, true)
  assert(storewrite.save(a, touched, "a moves the remote forward"))
  assert(publish.publish(a))
  fixture.caller_publish(a)

  local mine = check.must(store.load(b, id))
  mine.title = "the eventual winner"
  local ok, err = gate.commit_and_publish(b, mine, SPEC_TOUCH,
    ("spec %s"):format(mine.id:sub(1, 8)), "set")
  assert(ok, "the stale mutation prepares: " .. tostring(err))
  local pending = check.must(staging.list(b.root))
  assert(#pending == 1)
  local pushed, perr = native.execute(b.root, pending[1])
  assert(not pushed and perr == store.LOST_RACE)
  assert(native.sync(b))
  assert(check.must(refs.read_ref(b.root, pending[1].ref)) == refs.ZERO_SHA)
  local quarantine = "refs/gitboard/quarantined/lost-race/" .. pending[1].id
  assert(check.must(refs.read_ref(b.root, quarantine))
    == pending[1].sha, "the diagnosed transaction remains inspectable")
  check.must(store.list(b))
  local again, aerr = gate.commit_and_publish(b, mine, SPEC_TOUCH,
    ("spec %s"):format(mine.id:sub(1, 8)), "set")
  assert(again, "the re-run prepares against merged state: " .. tostring(aerr))
  fixture.caller_publish(b)
  fixture.caller_fetch(a)
  assert(check.must(store.load(a, mine.id)).title == "the eventual winner",
    "and the mutation reaches the remote")
end

-- Remote-backed mutations print the exact caller-owned transport plan at the
-- common boundary; a local-only mutation remains quiet.
local function test_commit_surfaces_remote_transport_but_local_stays_quiet()
  local _a, remote = init_shared("gate-render-publish")
  local remote_item = make_item()
  local seen, old_print = "", _G.print
  _G.print = function(msg: any) seen = seen .. tostring(msg) end
  local ok, detail = gate.commit_and_publish(remote, remote_item, nil,
    "new remote item", "new")
  _G.print = old_print
  assert(ok and detail:find("gitboard publish", 1, true) ~= nil, detail)
  assert(detail:find("NOT PUBLISHED", 1, true) ~= nil, detail)
  assert(seen == detail, "the returned transport plan is printed verbatim")

  local local_store = init_state_repo("gate-local-quiet")
  local local_item = make_item()
  seen, old_print = "", _G.print
  _G.print = function(msg: any) seen = seen .. tostring(msg) end
  local lok, ldetail = gate.commit_and_publish(local_store, local_item, nil,
    "new local item", "new")
  _G.print = old_print
  assert(lok and ldetail:find("confirmed=1", 1, true) ~= nil, ldetail)
  assert(seen == ldetail, "local publication prints its confirmation")
end

-- Graph writes include their parent/order side in the same claim check. The
-- holder can decompose its item, a foreign caller cannot, and an audited force
-- can repair it without implicitly releasing the claim.
local function test_graph_parent_mutations_obey_the_whole_item_claim()
  local s = init_state_repo("gate-graph-claim")
  local _root, parent = fixture.root_with_leaf(s)
  fixture.claim_item(s, parent, "holder")

  assert(graph.cmd_new(s, "foreign child", parent, nil, "", false, "",
      "", "", "stranger") ~= 0,
    "a foreign caller cannot rewrite the claimed parent's order")
  assert(graph.cmd_new(s, "holder child", parent, nil, "", false, "",
      "", "", "holder") == 0,
    "the exact holder may mutate the whole item")
  assert(check.must(store.load(s, parent)).claim == "holder",
    "the graph transition did not release the claim")
  assert(graph.cmd_new(s, "repair child", parent, nil, "", true,
      "repair ordering", "", "", "stranger") == 0,
    "an audited force may mutate a claimed graph target")
  assert(check.must(store.load(s, parent)).claim == "holder",
    "the forced graph repair did not release the claim")
end

-- A fetched board preserves every claim, but no global doing bound is
-- part of acquisition any more. Callers manage their own WIP locally;
-- Git coordinates only the per-item leases.
local function test_the_merged_board_carries_all_claims_without_a_global_bound()
  local a, b = init_shared("gate-bound")
  local ids: {string} = {}
  for _ = 1, flow.DOING_LIMIT do
    local it = make_item()
    ids[#ids + 1] = it.id
    assert(storewrite.save(a, it, "filler " .. fresh_id():sub(1, 8)))
  end
  assert(publish.publish(a))
  fixture.caller_publish(a)
  fixture.control_claim(a, ids, "one-worker")
  fixture.caller_fetch(b)
  check.must(store.list(b))
  local c = check.must(store.read(b))
  assert(check.must(read.doing_count(c)) >= flow.DOING_LIMIT,
    "claims remain observable even though their count is not a global gate")
end

-- A graph-derived stage change never releases a whole-item claim.
-- Claims move only through their explicit control operations.
local function test_containered_preserves_claims()
  local untouched = make_item()
  local c1 = fixture.make_index({untouched})
  assert(#check.must(gate.containered(c1, untouched)) == 0,
    "an unclaimed parent has nothing to clear")
  local held = make_item({claim = "session-A", reviewer = "review-1"})
  local c2 = fixture.make_index({held})
  local out = check.must(gate.containered(c2, held))
  assert(#out == 0 and held.claim == "session-A" and held.reviewer == "review-1",
    "the derived container stage leaves claim state untouched")
end

-- The one exception: a parent already awaiting a verdict (an open PR,
-- or mid-`request changes`) keeps its claim and PR untouched — a
-- routine child is not the decomposition that clears them the way a
-- bare todo/plan item's first child does.
local function test_containered_leaves_a_review_or_rework_parent_alone()
  local reviewing = make_item({claim = "session-A", pr = 9})
  local c1 = fixture.make_index({reviewing})
  assert(#check.must(gate.containered(c1, reviewing)) == 0,
    "an item awaiting a verdict has nothing cleared")
  assert(reviewing.claim == "session-A" and reviewing.pr == 9,
    "its claim and PR stand exactly as they were")

  local reworking = make_item({claim = "session-B", pr = 4,
      verdict = "request changes"})
  local c2 = fixture.make_index({reworking})
  assert(#check.must(gate.containered(c2, reworking)) == 0,
    "mid-rework is the same exception")
  assert(reworking.claim == "session-B" and reworking.pr == 4,
    "its claim and PR stand too")
end

-- A claimed item mid-rework with NO pr and NO result — the send-back
-- answered in place, not yet handed back over — is the same exception:
-- `_work.readddl`'s `role_view` maps a standing "request changes" to
-- "rework" on the verdict alone, no pr/result gate, so a PR-less
-- rework parent that gains a routine child must keep both its role
-- "work" (`_work.read.role`, what `take`'s container refusal reads)
-- and its live claim — never the old unconditional clear a bare
-- todo/plan item's first child still gets.
local function test_containered_leaves_a_pr_less_rework_parent_alone()
  local reworking = make_item({claim = "session-C",
      verdict = "request changes"})
  local child = make_item({parent = reworking.id})
  local c = fixture.make_index({reworking, child})
  assert(check.must(read.role(c, reworking.id)) == "work",
    "role_view keeps it work with no pr/result gate")
  assert(#check.must(gate.containered(c, reworking)) == 0,
    "so containered has nothing to clear")
  assert(reworking.claim == "session-C",
    "the claim survives — the old code wiped it here")
end

-- The take refusal counts what awaits a verdict by KIND: a research
-- handover outranking a take must be named "handover", never "diff"
-- — the noun `next`'s review reason already gets right (#1625).
local function test_review_debt_refusal_names_a_handover_not_a_diff()
  local handed = make_item({claim = "other", builders = "other",
      result = ("ab"):rep(32)})
  local taking = make_item()
  local c1 = fixture.make_index({handed, taking})
  local refusal, rerr1 = gate.review_debt_refusal(c1, {handed, taking}, "me", taking)
  assert(rerr1 == "", rerr1)
  assert(refusal ~= nil, "the handover outranks the todo take")
  assert(refusal:find("1 handover(s) await a verdict", 1, true) ~= nil,
    "names it a handover: " .. tostring(refusal))
  assert(not refusal:find("diff", 1, true),
    "never calls a handover a diff: " .. refusal)
  local diffed = make_item({claim = "other", builders = "other", pr = 3})
  local c2 = fixture.make_index({diffed, taking})
  local diff_refusal, rerr2 = gate.review_debt_refusal(c2, {diffed, taking}, "me", taking)
  assert(rerr2 == "", rerr2)
  assert(diff_refusal:find("1 diff(s) await a verdict", 1, true) ~= nil,
    "a diff's wording is unchanged: " .. tostring(diff_refusal))
end

-- The one carve-out: a lane repair — G8's child titled as
-- `flow.repair_title` writes, the same predicate `_work.readddl`'s
-- stage view ranks it by — is never held behind review debt, because
-- a red lane's fix cannot wait on a queue it did not grow. G8's other
-- children are ordinary work and wait like everyone else: on the live
-- board that outcome holds dozens of them.
local function test_review_debt_never_holds_a_lane_repair_back()
  local diffed = make_item({claim = "other", builders = "other", pr = 3})
  local repair = make_item({parent = flow.LANE_PARENT,
      title = flow.repair_title("release.yml")})
  local lodger = make_item({parent = flow.LANE_PARENT})
  local c = fixture.make_index({diffed, repair, lodger})
  local refusal, rerr = gate.review_debt_refusal(c, {diffed, repair, lodger},
    "me", repair)
  assert(rerr == "", rerr)
  assert(refusal == nil, "a lane repair is exempt: " .. tostring(refusal))
  local held, herr = gate.review_debt_refusal(c, {diffed, repair, lodger},
    "me", lodger)
  assert(herr == "", herr)
  assert(held ~= nil, "an ordinary child of G8 is not")
end

-- The distance guard: named on either involvement list refuses,
-- either half is enough, and an unnamed session is never involved.
local function test_distance_refusal_covers_builders_and_speccers()
  local built = make_item({builders = "me"})
  assert(gate.distance_refusal(built, "me") ~= nil, "a builder is refused")
  local specced = make_item({speccers = "me"})
  assert(gate.distance_refusal(specced, "me") ~= nil, "a speccer is refused")
  local stranger = make_item({builders = "someone-else"})
  assert(gate.distance_refusal(stranger, "me") == nil,
    "a session named on neither list is not refused")
  assert(gate.distance_refusal(stranger, "") == nil,
    "an unnamed session is never involved")
end

--- A spec sidecar with the given body, through the spec verb.
local function write_spec(s: store.Store, id: string, name: string,
    body: string)
  local path = fs.join(fixture.tmpdir, ("owner-%s.md"):format(name))
  assert(fs.write(path, body))
  assert(gitspec.cmd_spec(s, id, path) == 0, "spec should be accepted")
  fixture.caller_publish(s)
end

--- A workable, placed, specced leaf whose `repo` was written the way
--- stale data got there — straight into the file, past the verbs —
--- on a board that reads its origin as `cosmic-lua/cosmic`.
local function foreign_leaf(name: string, body: string): store.Store, string
  local s = init_shared("owner-" .. name)
  fixture.github_origin(s, "cosmic-lua/cosmic")
  local _, leaf = fixture.root_with_leaf(s)
  write_spec(s, leaf, name, body)
  local it = check.must(store.load(s, leaf))
  it.repo = "whilp/cosmopolitan"
  assert(storewrite.save(s, it, "fixture: a repo written before the rule"))
  assert(publish.publish(s))
  fixture.caller_publish(s)
  assert(check.must(store.load(s, leaf)).repo == "whilp/cosmopolitan",
    "the caller-confirmed stale repo field is canonical")
  assert(owner.board_owner(s) == "cosmic-lua",
    "the board owner still comes from its configured GitHub remote")
  return s, leaf
end

-- Legacy board data may still name a foreign repository, but the v3 ready bar
-- is commit/spec-local and performs no provider ownership gate. Write-time
-- validation remains covered in `gitowner_test`; acquisition stays offline.
local function test_a_legacy_foreign_owner_repo_does_not_add_a_ready_bar()
  local s, leaf = foreign_leaf("foreign", fixture.READY_SPEC)
  local problems = gitready.ready_problems(s, check.must(store.load(s, leaf)))
  assert(#problems == 0, "no provider-owned ready problem: "
    .. table.concat(problems, "; "))
  fixture.claim_item(s, leaf, "session-a")
end

-- The same owner as the board passes, whatever the repository's name.
local function test_a_same_owner_repo_passes_the_bar()
  local s, leaf = foreign_leaf("same", fixture.READY_SPEC)
  assert(graph.cmd_set(s, leaf, nil, "cosmic-lua/cosmopolitan", nil) == 0,
    "the repair the problem names is accepted")
  fixture.caller_publish(s)
  local problems = gitready.ready_problems(s, check.must(store.load(s, leaf)))
  assert(#problems == 0, "a same-owner repo is no problem: "
    .. table.concat(problems, "; "))
  fixture.claim_item(s, leaf, "session-a")
end

-- The deliberate cross-owner case: the item declares the slug in its
-- `access` field, and the repo is accepted as stated.
local function test_a_foreign_owner_declared_as_access_passes_the_bar()
  local s, leaf = foreign_leaf("declared", fixture.READY_SPEC)
  assert(graph.cmd_set(s, leaf, nil, nil, nil, nil, nil, nil, nil,
      {"whilp/cosmopolitan"}) == 0, "the field is declarable")
  fixture.caller_publish(s)
  local problems = gitready.ready_problems(s, check.must(store.load(s, leaf)))
  assert(#problems == 0, "a declared cross-owner repo is no problem: "
    .. table.concat(problems, "; "))
  fixture.claim_item(s, leaf, "session-a")
end

-- A board with no GitHub origin has no owner to compare against and
-- skips the rule — the local-only waiver the handover gate uses.
local function test_a_board_with_no_origin_skips_the_owner_rule()
  local s = init_state_repo("owner-local")
  local _, leaf = fixture.root_with_leaf(s)
  write_spec(s, leaf, "local", fixture.READY_SPEC)
  local it = check.must(store.load(s, leaf))
  it.repo = "whilp/cosmopolitan"
  assert(storewrite.save(s, it, "fixture: a repo on a local-only board"))
  assert(publish.publish(s))
  assert(owner.board_owner(s) == nil, "no origin, no owner")
  local problems = gitready.ready_problems(s, check.must(store.load(s, leaf)))
  assert(#problems == 0, "nothing to compare against: "
    .. table.concat(problems, "; "))
end

-- The dependency half of the same bar: an item waiting on something
-- still open misses it, and the problem names which dependency holds
-- it — a bare refusal would leave a reader guessing at a bug.
local function test_an_unresolved_dependency_is_a_ready_problem()
  local s = init_state_repo("depends-bar")
  local root, leaf = fixture.root_with_leaf(s)
  write_spec(s, leaf, "depends", fixture.READY_SPEC)
  local blocker = fixture.file_item(s, "the question in the way", root)
  assert(#gitready.ready_problems(s, check.must(store.load(s, leaf))) == 0,
    "the leaf meets the bar before the edge is declared")
  assert(gitdepend.cmd_depend(s, leaf, blocker) == 0, "the edge should land")
  local problems = gitready.ready_problems(s, check.must(store.load(s, leaf)))
  assert(#problems == 1, "exactly the one problem: "
    .. table.concat(problems, "; "))
  assert(problems[1]:find("is not done yet", 1, true) ~= nil
    and problems[1]:find(tail.handle(blocker), 1, true) ~= nil
    and problems[1]:find("the question in the way", 1, true) ~= nil,
    "it names the handle and the title: " .. problems[1])
end

-- The blocker's `done` frees the waiter with no second verb: the field
-- still names it, and the bar simply stops reporting it.
local function test_a_finished_dependency_clears_the_ready_problem()
  local s = init_state_repo("depends-freed")
  local root, leaf = fixture.root_with_leaf(s)
  write_spec(s, leaf, "freed", fixture.READY_SPEC)
  local blocker = fixture.file_item(s, "the blocker", root)
  assert(gitdepend.cmd_depend(s, leaf, blocker) == 0)
  assert(gitdone.cmd_done(s, blocker, "completed", false, "") == 0,
    "the blocker should finish")
  local it = check.must(store.load(s, leaf))
  assert(#(it.depends_on or {}) == 1, "the edge is still declared")
  assert(#gitready.ready_problems(s, it) == 0,
    "and a finished dependency holds nothing back")
end

-- A dependency naming no item at all is reported too, rather than read
-- as resolved: an id pointing at nothing is a repair, not a green light.
local function test_a_dependency_naming_no_item_is_a_ready_problem()
  local s = init_state_repo("depends-absent")
  local _root, leaf = fixture.root_with_leaf(s)
  write_spec(s, leaf, "absent", fixture.READY_SPEC)
  local it = check.must(store.load(s, leaf))
  it.depends_on = {"3HyArM3A3zHuRxn3VYCvKmUZ7KW"}
  assert(storewrite.save(s, it, "fixture: a dependency on nothing"))
  assert(publish.publish(s))
  local problems = gitready.ready_problems(s, check.must(store.load(s, leaf)))
  assert(#problems == 1 and problems[1]:find("not on the board", 1, true) ~= nil,
    "an id naming nothing is reported: " .. table.concat(problems, "; "))
end
