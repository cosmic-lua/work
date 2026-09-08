--- Claim lease semantics, independent of transport and storage. A claim is
--- identified by the commit which acquired it, while its current deadline is
--- two hours after the newest acquire/force/renew control commit. Expiry is
--- deliberately acquisition-only: it lets another caller race for the item,
--- but does not erase the old claimant's work or manufacture an expiry commit.
local identity = require("_work.identity")

local LEASE_S < const > = 2 * 60 * 60
local FUTURE_SKEW_S < const > = 5 * 60

local record State
  holder: string
  root: string
  control: string
  acquired_at: integer
  renewed_at: integer
  expires_at: integer
  product_base: string
end

local enum Status
  "none"
  "active"
  "expired"
  "future"
end

--- Classify a lease at the caller's current time. Exactly at expires_at the
--- lease is expired. A control commit more than five minutes in the future is
--- invalid rather than accidentally receiving a longer lease.
local function status(st: State | nil, now: integer): Status
  if st == nil or (st.holder or "") == "" then
    return "none"
  end
  if st.renewed_at > now + FUTURE_SKEW_S then
    return "future"
  end
  if now >= st.expires_at then
    return "expired"
  end
  return "active"
end

--- Refusal for acquiring an item. Repeating take under the same ACTIVE caller
--- is an idempotent success (the caller distinguishes it through `owned`);
--- notably, it does not renew. An expired claim is free for every caller.
local function take_refusal(st: State | nil, caller: string, now: integer,
    force: boolean, why: string): string | nil, boolean
  local bad = identity.identity_refusal(caller)
  if bad ~= nil then return bad, false end
  if caller == "" then return "a claim requires a minted caller id", false end
  local kind = status(st, now)
  if kind == "future" then
    return "claim timestamp is more than five minutes in the future", false
  end
  if kind ~= "active" then return nil, false end
  if st == nil then return "active claim has no state", false end
  if st.holder == caller then return nil, true end
  if not force then
    return ("item is claimed by %s until %d"):format(st.holder, st.expires_at), false
  end
  if (why or ""):match("^%s*$") then
    return "force takeover requires --why", false
  end
  return nil, false
end

--- Refusal for an ordinary item mutation. Active claims freeze the whole item
--- against every other caller; audited force is the only early escape.
local function mutation_refusal(st: State | nil, caller: string, now: integer,
    force: boolean, why: string): string | nil
  local kind = status(st, now)
  if kind == "future" then
    return "claim timestamp is more than five minutes in the future"
  end
  if kind ~= "active" then return nil end
  if st == nil then return "active claim has no state" end
  if st.holder == caller then return nil end
  if not force then
    return ("item is frozen by %s until %d"):format(st.holder, st.expires_at)
  end
  if (why or ""):match("^%s*$") then
    return "forced mutation requires --why"
  end
  return nil
end

--- Renewal is manual and only the exact per-run caller holding a still-active
--- lease may do it. It keeps `root` and advances only the control timestamp.
local function renew_refusal(st: State | nil, caller: string,
    now: integer): string | nil
  local kind = status(st, now)
  if kind == "future" then
    return "claim timestamp is more than five minutes in the future"
  end
  if kind ~= "active" then return "only an active claim can be renewed" end
  if st == nil then return "active claim has no state" end
  if st.holder ~= caller then
    return ("claim belongs to %s, not %s"):format(st.holder, caller)
  end
  return nil
end

--- Drop belongs to the holder, even after logical expiry, provided its commit
--- still wins the item-ref CAS. A foreign drop is an audited force operation.
local function drop_refusal(st: State | nil, caller: string, now: integer,
    force: boolean, why: string): string | nil
  local kind = status(st, now)
  if kind == "future" then
    return "claim timestamp is more than five minutes in the future"
  end
  if kind == "none" then return "item has no claim" end
  if st == nil then return "claim has no state" end
  if st.holder == caller then return nil end
  if not force then return ("claim belongs to %s, not %s"):format(st.holder, caller) end
  if (why or ""):match("^%s*$") then return "forced drop requires --why" end
  return nil
end

--- Stable product branch for every attempt. Renewal keeps the initial root,
--- and therefore keeps this branch; a post-expiry acquisition gets a new root
--- and cannot collide with the old attempt.
local function branch(item_id: string, root: string): string
  return ("work/%s/%s"):format(item_id:sub(-8), root:sub(1, 12))
end

local record claim
  LEASE_S: integer
  FUTURE_SKEW_S: integer
  type State = State
  type Status = Status
  status: function(st: State | nil, now: integer): Status
  take_refusal: function(st: State | nil, caller: string, now: integer,
  force: boolean, why: string): string | nil, boolean
  mutation_refusal: function(st: State | nil, caller: string, now: integer,
  force: boolean, why: string): string | nil
  renew_refusal: function(st: State | nil, caller: string, now: integer): string | nil
  drop_refusal: function(st: State | nil, caller: string, now: integer,
  force: boolean, why: string): string | nil
  branch: function(item_id: string, root: string): string
end

local M: claim = {
  LEASE_S = LEASE_S,
  FUTURE_SKEW_S = FUTURE_SKEW_S,
  status = status,
  take_refusal = take_refusal,
  mutation_refusal = mutation_refusal,
  renew_refusal = renew_refusal,
  drop_refusal = drop_refusal,
  branch = branch,
}

return M
