#!/usr/bin/env cosmic
-- The `handoff` action: a live claim transferred to a reviewer in one
-- commit, so the review handoff costs one publish instead of two and
-- the item is never briefly unclaimed between them.

local check = require("cosmic.check")
local fs = require("cosmic.fs")
local fixture = require("_work.fixture")
local refs = require("_work.refs")
local boardtree = require("_work.boardtree")
local native = require("_work.stateclaim")

local NOW < const > = 1900000000
local BUILDER < const > = "0123456789abcdef0123456789abcdef"
local REVIEWER < const > = "abcdef0123456789abcdef0123456789"
local CO_BUILDER < const > = "fedcba9876543210fedcba9876543210"
local BASE < const > = "0123456789012345678901234567890123456789"
local HANDOVER < const > = "cafe" .. ("0"):rep(36)

--- A board with one item that has handed over, optionally naming
--- BUILDER among the sessions that built it.
local function setup(name: string, builders: string): string, string
  local root = fs.join(fixture.tmpdir, "handoff-" .. name)
  assert(fs.remove_all(root)); assert(fs.make_dirs(root .. "/items/a"))
  assert(fs.make_dirs(root .. "/claims"))
  fixture.git(root, {"init", "-q"})
  assert(fs.write(root .. "/format", "6\n"))
  local meta = "kind: task\ntitle: A\nhandover_head: " .. HANDOVER .. "\n"
  if builders ~= "" then meta = meta .. "builders: " .. builders .. "\n" end
  assert(fs.write(root .. "/items/a/meta", meta))
  fixture.git(root, {"add", "."})
  fixture.git(root, {"commit", "-qm", "base"})
  return root, check.must(refs.read_ref(root, "HEAD"))
end

local function apply(root: string, result: native.Result): string
  assert(next(result.refused) == nil, "a refusal blocked the fixture")
  for _, c in ipairs(result.changes) do
    if c.delete then assert(fs.remove(root .. "/" .. c.path))
    else assert(fs.write(root .. "/" .. c.path, c.content)) end
  end
  fixture.git(root, {"add", "."})
  fixture.git(root, {"commit", "--allow-empty", "-qm", "claim"})
  return check.must(refs.read_ref(root, "HEAD"))
end

local function act(root: string, head: string, action: native.Action,
    who: string): native.Result
  return native.prepare(root, head, {{id = "a", product_base = BASE}}, action,
    who, NOW + 1, false, "")
end

local function claimed(root: string, head: string): boardtree.Claim
  local view = check.must(require("_work.boardread").list(root, head, NOW + 2))
  return view.claims_by_id["a"]
end

local function test_handoff_moves_the_holder_and_keeps_the_product_base()
  local root, head = setup("transfer", "")
  head = apply(root, act(root, head, "take", BUILDER))
  local before = claimed(root, head)
  local moved = act(root, head, "handoff", REVIEWER)
  assert(next(moved.refused) == nil, "handoff refused")
  head = apply(root, moved)
  local after = claimed(root, head)
  assert(after.holder == REVIEWER, "holder moved: " .. after.holder)
  assert(after.product_base == before.product_base,
    "same product base: the reviewer measures the same diff")
end

local function test_handoff_mints_a_fresh_root_so_the_reviewer_gets_its_own_branch()
  -- The builder's work branch is named from its claim root and still
  -- exists; `worktree` never reuses a branch, so a preserved root would
  -- leave the reviewer unable to check anything out.
  local root, head = setup("branch", "")
  head = apply(root, act(root, head, "take", BUILDER))
  local before = claimed(root, head)
  head = apply(root, act(root, head, "handoff", REVIEWER))
  local after = claimed(root, head)
  assert(after.id ~= before.id,
    "a fresh claim root: " .. after.id .. " vs " .. before.id)
end

local function test_handoff_is_one_commit_not_a_drop_and_a_take()
  local root, head = setup("single", "")
  head = apply(root, act(root, head, "take", BUILDER))
  local moved = act(root, head, "handoff", REVIEWER)
  assert(#moved.changes == 1, "one change, got " .. tostring(#moved.changes))
  assert(not moved.changes[1].delete, "the claim is rewritten, never deleted")
end

local function test_handoff_refuses_a_session_that_built_the_item()
  -- A co-builder that never held the claim is the case the distance
  -- rule exists for: it would pass every other check. The holder
  -- itself is refused one step earlier, for holding it.
  local root, head = setup("distance", CO_BUILDER)
  head = apply(root, act(root, head, "take", BUILDER))
  local why = act(root, head, "handoff", CO_BUILDER).refused["a"]
  assert(why ~= nil, "a builder may not take the review claim")
  assert(why:find("built/specced", 1, true) ~= nil, "got: " .. why)
end

local function test_handoff_refuses_when_nothing_was_handed_over()
  local root = fs.join(fixture.tmpdir, "handoff-nohandover")
  assert(fs.remove_all(root)); assert(fs.make_dirs(root .. "/items/a"))
  assert(fs.make_dirs(root .. "/claims"))
  fixture.git(root, {"init", "-q"})
  assert(fs.write(root .. "/format", "6\n"))
  assert(fs.write(root .. "/items/a/meta", "kind: task\ntitle: A\n"))
  fixture.git(root, {"add", "."}); fixture.git(root, {"commit", "-qm", "base"})
  local head = check.must(refs.read_ref(root, "HEAD"))
  head = apply(root, act(root, head, "take", BUILDER))
  local why = act(root, head, "handoff", REVIEWER).refused["a"]
  assert(why ~= nil and why:find("handed over nothing", 1, true) ~= nil,
    "got: " .. tostring(why))
end

local function test_handoff_refuses_an_unclaimed_item()
  local root, head = setup("unclaimed", "")
  local why = act(root, head, "handoff", REVIEWER).refused["a"]
  assert(why ~= nil and why:find("live claim", 1, true) ~= nil,
    "got: " .. tostring(why))
end

local function test_handoff_refuses_the_session_that_already_holds_it()
  local root, head = setup("self", "")
  head = apply(root, act(root, head, "take", BUILDER))
  local why = act(root, head, "handoff", BUILDER).refused["a"]
  assert(why ~= nil, "already-held is refused")
end

local function test_handoff_seizes_a_live_claim_without_the_holder_consenting()
  -- The widening this action introduces, pinned deliberately rather than
  -- left as a side effect: a third session takes a LIVE claim it does not
  -- hold, with no --force and no --why, which every other path refuses.
  --
  -- What bounds it is `handover_head`. Only the holder's own `take` sets
  -- that, and setting it is the builder saying "I am done, review me" — so
  -- the seizure is confined to items whose holder has already asked for a
  -- reviewer. An item still being built cannot be taken this way, which
  -- `_work/snapshot_authority_test.tl` pins from the other side.
  local root, head = setup("seize", "")
  head = apply(root, act(root, head, "take", BUILDER))
  local before = claimed(root, head)
  assert(before.holder == BUILDER, "the builder holds it")
  local moved = act(root, head, "handoff", REVIEWER)
  assert(next(moved.refused) == nil,
    "a non-builder takes it with no force and no why")
  head = apply(root, moved)
  assert(claimed(root, head).holder == REVIEWER, "and the holder moved")
end
