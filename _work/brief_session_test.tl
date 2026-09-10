#!/usr/bin/env cosmic
-- A brief names the session its item is ALREADY claimed under
-- (`it.claim`) and never mints a claim string of its own — the exact
-- 32-hex identity `claim --session` (and `verdict`, `take`, `drop`)
-- accept, so the string a brief hands an agent is always one
-- `gitboard session new` actually minted, never a printed label the
-- mutating verbs go on to refuse.

local check = require("cosmic.check")
local brief = require("_work.brief")
local claimsession = require("_work.claimsession")
local fixture = require("_work.fixture")
local item = require("_work.item")
local store = require("_work.store")
local storewrite = require("_work.storewrite")

local init_state_repo = fixture.init_state_repo
local give_spec = fixture.give_spec
local root_with_leaf = fixture.root_with_leaf

local BASE < const > = ("a"):rep(40)
local HEAD < const > = ("b"):rep(40)

--- Run brief.cmd_brief and capture exactly what it prints via
--- print() — the same swap-and-restore pattern `_work.brief_test` uses.
--- @param s store.Store The store
--- @param kind string The brief kind
--- @param id string The item id
--- @return integer cmd_brief's exit code
--- @return string Every print()'d line, newline-joined
local function brief_and_capture(s: store.Store, kind: string, id: string): integer, string
  local old_print = _G.print
  local lines: {string} = {}
  _G.print = function(...: any)
    local parts: {string} = {}
    for i = 1, select("#", ...) do
      parts[i] = tostring((select(i, ...)))
    end
    lines[#lines + 1] = table.concat(parts, "\t")
  end
  local ok, result = pcall(brief.cmd_brief, s, kind, id)
  _G.print = old_print
  if not ok then
    error(result, 0)
  end
  return result, table.concat(lines, "\n")
end

--- Record `id` as handed over by `builder`, without touching its claim
--- (`it.claim`/`it.claim_base` are projected from a claim-batch pointer at
--- read time — `_work.claimprojection` — never from the item's own
--- history, so establishing one goes through `fixture.claim_item`,
--- separately, wherever a test needs one).
local function record_handover(s: store.Store, id: string, builder: string)
  local it = check.must(store.load(s, id))
  it.repo = "acme/widgets"
  it.handover_head = HEAD
  assert(item.record_involvement(it.builders, builder))
  assert(storewrite.save(s, it,
      ("take %s by %s head:%s"):format(id:sub(1, 8), builder, HEAD:sub(1, 12))))
end

local function test_builder_brief_names_the_exact_claim_session()
  local s = init_state_repo("brief-session-builder")
  local _, leaf = root_with_leaf(s)
  give_spec(s, leaf)
  local session = claimsession.mint()
  fixture.claim_item(s, leaf, session, BASE)
  local code, out = brief_and_capture(s, "builder", leaf)
  assert(code == 0, "a claimed, specced item earns its builder brief: " .. out)
  assert(session:match("^[0-9a-f]+$") ~= nil and #session == 32,
    "the fixture's own minted session is the 32-hex shape `claim --session` accepts")
  assert(out:find("claimed under session " .. session, 1, true) ~= nil,
    "the verdict line names the exact claim, not a minted label: " .. out)
end

local function test_review_brief_fills_a_claim_off_its_builders()
  local s = init_state_repo("brief-session-review")
  local _, leaf = root_with_leaf(s)
  give_spec(s, leaf)
  record_handover(s, leaf, "session-a")
  local reviewer = claimsession.mint()
  fixture.claim_item(s, leaf, reviewer, BASE)
  local code, out = brief_and_capture(s, "review", leaf)
  assert(code == 0, "a claim distinct from every builder earns the review brief: " .. out)
  assert(out:find("<REVIEW_SESSION>", 1, true) == nil,
    "the placeholder is filled from the claim, not left for the caller")
  assert(claimsession.is_id(reviewer), "the reviewing session is a minted 32-hex id")
  assert(out:find("--session " .. reviewer, 1, true) ~= nil,
    "the verdict command in the body carries that same id: " .. out)
  assert(out:find("claimed under session " .. reviewer, 1, true) ~= nil,
    "and the closing verdict line repeats it: " .. out)
end

local function test_review_brief_refuses_a_claim_on_its_own_builders()
  local s = init_state_repo("brief-session-selfreview")
  local _, leaf = root_with_leaf(s)
  give_spec(s, leaf)
  record_handover(s, leaf, "session-a")
  fixture.claim_item(s, leaf, "session-a", BASE)
  local code, out = brief_and_capture(s, "review", leaf)
  assert(code ~= 0,
    "the item's own claim holder built it — a review needs distance: " .. out)
  assert(out:find("\n", 1, true) == nil,
    "the refusal is one verdict line, no body: " .. out)
  assert(out:find("is still claimed by the session that built it", 1, true) ~= nil,
    "the refusal names the reason, not just a generic failure: " .. out)
  assert(out:find("gitboard session new", 1, true) == nil,
    "this is the distance refusal, not the no-claim-at-all one")
end

local function test_refine_brief_carries_no_session_clause_when_unclaimed()
  local s = init_state_repo("brief-session-refine")
  local _, leaf = root_with_leaf(s)
  give_spec(s, leaf)
  local code, out = brief_and_capture(s, "refine", leaf)
  assert(code == 0, "an unclaimed item still earns its refine brief: " .. out)
  assert(out:find("claim it as", 1, true) == nil,
    "the retired minted-label phrasing is gone: " .. out)
  assert(out:find("refine%-[%w]+%-[%w]+") == nil,
    "no `<kind>-<handle>-...` label survives either: " .. out)
  assert(out:find("mint a session with `gitboard session new`", 1, true) ~= nil,
    "the ordinary unclaimed case points at how to get one instead: " .. out)
end
