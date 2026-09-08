#!/usr/bin/env cosmic
-- Focused format-4 fsck coverage: a healthy shared manifest has a bridge for
-- every row, while raw Git damage is reported even when ordinary projection
-- can no longer load the item.
local check = require("cosmic.check")
local child = require("cosmic.child")
local fixture = require("_work.fixture")
local fsck = require("_work.gitfsck")
local gitclaim = require("_work.gitclaim")
local prepared = require("_work.prepared")
local refs = require("_work.refs")
local store = require("_work.store")
local storewrite = require("_work.storewrite")

local CALLER < const > = "0123456789abcdef0123456789abcdef"

local function fsck_and_capture(s: store.Store): integer, string
  local old_print = _G.print
  local lines: {string} = {}
  _G.print = function(...: any)
    local parts: {string} = {}
    for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
    lines[#lines + 1] = table.concat(parts, "\t")
  end
  local code = fsck.cmd_fsck(s)
  _G.print = old_print
  return code, table.concat(lines, "\n")
end

local function request(s: store.Store, id: string, batch: string,
    now: integer): gitclaim.Request
  local ref = gitclaim.target_item_ref(id)
  local tip = check.must(refs.read_ref(s.root, ref))
  return {root = s.root, id = id, source_ref = ref, target_ref = ref,
    remote = "origin", batch = batch, caller = CALLER, action = "take",
    product_base = tip, force = false, why = "", now = now}
end

local function test_claim_batches_must_have_a_bridge_for_every_member()
  local s = fixture.init_state_repo("fsck-claim-batch-partial")
  local _root, first = fixture.root_with_leaf(s)
  local second = fixture.file_item(s, "second claimed item", "")
  local second_ref = gitclaim.target_item_ref(second)
  local before = (check.must(child.run({"git", "rev-parse", second_ref},
        {cwd = s.root})).stdout:gsub("%s+$", ""))
  local now = os.time()
  local prepared_batch = gitclaim.prepare_batch({request(s, first, "batch-fsck", now),
      request(s, second, "batch-fsck", now)}).prepared
  assert(prepared_batch ~= nil, "the complete claim batch prepared")
  assert(prepared.promote_local(s.root, prepared_batch.transaction))
  assert(store.close(s))
  local healthy, healthy_out = fsck_and_capture(s)
  assert(healthy == 0, healthy_out)

  -- Retain the manifest and one bridge, but rewind one member past its bridge:
  -- exactly the partial external update fsck must distinguish from a healthy
  -- atomic transaction.
  fixture.git(s.root, {"update-ref", second_ref, before})
  assert(store.close(s))
  local code, out = fsck_and_capture(s)
  assert(code ~= 0, "a partial batch is corrupt: " .. out)
  assert(out:find("claim batch", 1, true) ~= nil
    and out:find(second:sub(1, 8), 1, true) ~= nil
    and out:find("no first-parent claim bridge", 1, true) ~= nil, out)
end

local function test_an_unresolvable_claim_batch_pointer_is_named()
  local s = fixture.init_state_repo("fsck-claim-batch-orphan")
  local _root, id = fixture.root_with_leaf(s)
  local it = check.must(store.load(s, id))
  it.claim_batch = ("0"):rep(40)
  assert(storewrite.save(s, it, "hand-edited missing claim batch"))
  assert(store.close(s))
  local code, out = fsck_and_capture(s)
  assert(code ~= 0, "an unresolvable claim batch pointer is corrupt: " .. out)
  assert(out:find("claim_batch " .. ("0"):rep(40) .. " does not resolve", 1, true)
    ~= nil, out)
end
