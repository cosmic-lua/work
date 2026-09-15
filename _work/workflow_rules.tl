--- Pure workflow rules shared by native verbs and raw snapshot validation.
local item = require("_work.item")
local itemtree = require("_work.itemtree")
local boardtree = require("_work.boardtree")
local claim = require("_work.claim")
local spec = require("_work.spec")

local record ChildState
  any: boolean
  open: item.Item | nil
  completed: boolean
end

--- Child facts used by outcome completion and raw final-state validation.
local function child_state(items: {item.Item}, parent: string): ChildState
  local out: ChildState = {any = false, open = nil, completed = false}
  for _, child in ipairs(items) do
    if child.parent == parent then
      out.any = true
      if item.is_open(child) and out.open == nil then out.open = child end
      if child.resolution == "completed" then out.completed = true end
    end
  end
  return out
end

--- Whether `session` helped build or specify an item under review.
local function distance_refusal(it: item.Item, session: string): string | nil
  if session == "" then return nil end
  for _, name in ipairs(it.builders or {}) do
    if name == session then
      return ("REFUSED: %s built/specced %s — the verdict needs a fresh "
        .. "context; recording it anyway needs --force --why"):format(
        session, it.id:sub(1, 8))
    end
  end
  for _, name in ipairs(it.speccers or {}) do
    if name == session then
      return ("REFUSED: %s built/specced %s — the verdict needs a fresh "
        .. "context; recording it anyway needs --force --why"):format(
        session, it.id:sub(1, 8))
    end
  end
  return nil
end

--- Whether one claim may be transferred to `author` as a review handoff.
---
--- A handoff keeps the claim identity and product base and moves only the
--- holder, so the reviewer judges the exact commit that was handed over on
--- the exact branch it was built on. Both the proposing side
--- (`_work.stateclaim`'s `prepare`) and the admitting side
--- (`_work.snapshot_validate`) call this, because a published snapshot is
--- validated independently of whatever composed it.
--- @param it item.Item The item whose claim is moving
--- @param old boardtree.Claim The claim as the board currently holds it
--- @param author string The session the claim is moving to
--- @return string | nil The refusal, nil when the transfer is allowed
local function handoff_refusal(it: item.Item, old: boardtree.Claim,
    author: string): string | nil
  if old.holder == author then
    return "item is already claimed by this session"
  end
  if (it.handover_head or "") == "" then
    return "handoff is for an item awaiting review; this one has handed over nothing"
  end
  return distance_refusal(it, author)
end

--- Require append-only workflow attribution to name the logical author.
local function attribution_refusal(names: {string}, author: string,
    message: string): string | nil
  if author == "gitboard" then return nil end
  for _, name in ipairs(names) do if name == author then return nil end end
  return message
end

--- Record attribution through the same identity rule the validator checks.
local function attribute(names: {string}, author: string): boolean, string
  return item.record_involvement(names, author)
end

local function claim_acquisition_refusal(value: boardtree.Claim,
    author: string, now: integer): string | nil
  if value.holder ~= author or value.acquired_at ~= value.renewed_at
  or value.expires_at ~= value.renewed_at + claim.LEASE_S
  or value.renewed_at > now + claim.FUTURE_SKEW_S
  or #value.product_base ~= 40
  or not value.product_base:match("^[0-9a-f]+$") then
    return "invalid claim acquisition"
  end
  return nil
end

local function claim_renewal_refusal(old: boardtree.Claim,
    new: boardtree.Claim): string | nil
  if new.holder ~= old.holder or new.acquired_at ~= old.acquired_at
  or new.product_base ~= old.product_base or new.renewed_at < old.renewed_at
  or new.expires_at ~= new.renewed_at + claim.LEASE_S then
    return "invalid claim renewal"
  end
  return nil
end

--- The authoritative deliverable a verdict judges; product wins if both exist.
local function handover_evidence(it: item.Item): string, string
  if (it.handover_head or "") ~= "" then
    return it.handover_head or "", "product"
  end
  if (it.result or "") ~= "" then return it.result or "", "research" end
  return "", ""
end

local type EvidenceResolver = function(item.Item, string, string): string | nil, string

--- Resolve the named deliverable and require it to be the current handover.
local function verdict_evidence(it: item.Item, named: string,
    resolve: EvidenceResolver, mismatch: string): string | nil, string
  local evidence, kind = handover_evidence(it)
  if evidence == "" then return nil, "item has no commit handover to judge" end
  local canonical, err = resolve(it, kind, named)
  if canonical == nil then return nil, err end
  if canonical ~= evidence then return nil, mismatch:format(canonical, evidence) end
  return canonical, ""
end

--- A research handover must have some specification to hand over.
local function research_spec_refusal(id: string,
    prose: itemtree.Spec): string | nil
  if prose.change ~= "" or prose.non_goals ~= "" then return nil end
  return ("%s has no spec — a research handover hands the spec over, "
    .. "and there is none"):format(id:sub(1, 8))
end

--- Worked completion needs acceptance unless this is an audited repair.
local function completion_review_refusal(it: item.Item,
    force: boolean): string | nil
  if force or (it.verdict or "") == "accept" then return nil end
  if (it.pr or 0) ~= 0 then
    return ("%s has PR #%d awaiting a verdict — done after an accept, "
      .. "or `drop` releases the handover"):format(it.id:sub(1, 8), it.pr or 0)
  end
  if #(it.builders or {}) > 0 then
    return ("%s has no PR and no accept — an evidence-only item takes "
      .. "a verdict too; record one (`gitboard verdict`), or end it "
      .. "without review via --force --why"):format(it.id:sub(1, 8))
  end
  return nil
end

--- Pure shape of an accepted or force-completed research landing.
local function research_landing_refusal(it: item.Item, reason: string,
    landed: string, force: boolean): string | nil
  local result = it.result or ""
  if reason ~= "completed" or (it.handover_head or "") ~= ""
  or result == "" then return nil end
  if (it.verdict or "") ~= "accept" then
    if landed ~= "" then return "--landed belongs to completed accepted work" end
    return nil
  end
  if (it.verdict_head or "") ~= result then
    return "acceptance must name the current research handover"
  end
  if landed == "" and not force then
    return "completed accepted work names its landed commit with --landed"
  end
  if landed ~= "" and landed ~= result and not force then
    return "research landing does not name published result"
  end
  return nil
end

--- Pure shape of a completed accepted product landing; ancestry is caller-owned.
local function product_landing_refusal(it: item.Item, reason: string,
    landed: string, force: boolean): string | nil
  local handed = it.handover_head or ""
  if reason ~= "completed" or (it.verdict or "") ~= "accept"
  or handed == "" then return nil end
  if (it.verdict_head or "") ~= handed then
    return "acceptance must name the current handover commit"
  end
  if landed == "" and not force then
    return "completed accepted work names its landed commit with --landed"
  end
  return nil
end

--- Repositories reached by the spec but absent from the item's access grant.
local function undeclared_repos(it: item.Item, prose: itemtree.Spec): {string}
  local declared: {string: boolean} = {}
  for _, repo in ipairs(it.access or {}) do declared[repo:lower()] = true end
  local own = (it.repo or ""):lower()
  local out: {string} = {}
  for _, repo in ipairs(spec.reached_repos(spec.document(prose))) do
    if repo ~= own and not declared[repo] then out[#out + 1] = repo end
  end
  return out
end

--- Spec-bar and declared-access issues shared by take and snapshot preflight.
local function readiness_issues(it: item.Item, prose: itemtree.Spec): {string}
  local out: {string} = {}
  for _, gap in ipairs(spec.ready_gaps(prose)) do
    out[#out + 1] = "spec " .. gap
  end
  for _, repo in ipairs(undeclared_repos(it, prose)) do
    out[#out + 1] = "undeclared repository " .. repo
  end
  return out
end

local record Module
  type ChildState = ChildState
  child_state: function({item.Item}, string): ChildState
  distance_refusal: function(item.Item, string): string
  handoff_refusal: function(item.Item, boardtree.Claim, string): string
  attribution_refusal: function({string}, string, string): string
  attribute: function({string}, string): boolean, string
  claim_acquisition_refusal: function(boardtree.Claim, string, integer): string
  claim_renewal_refusal: function(boardtree.Claim, boardtree.Claim): string
  handover_evidence: function(item.Item): string, string
  verdict_evidence: function(item.Item, string, EvidenceResolver, string): string | nil, string
  research_spec_refusal: function(string, itemtree.Spec): string
  completion_review_refusal: function(item.Item, boolean): string
  research_landing_refusal: function(item.Item, string, string,
  boolean): string
  product_landing_refusal: function(item.Item, string, string,
  boolean): string
  undeclared_repos: function(item.Item, itemtree.Spec): {string}
  readiness_issues: function(item.Item, itemtree.Spec): {string}
end
local M: Module = {
  child_state = child_state,
  distance_refusal = distance_refusal,
  handoff_refusal = handoff_refusal,
  attribution_refusal = attribution_refusal,
  attribute = attribute,
  claim_acquisition_refusal = claim_acquisition_refusal,
  claim_renewal_refusal = claim_renewal_refusal,
  handover_evidence = handover_evidence,
  verdict_evidence = verdict_evidence,
  research_spec_refusal = research_spec_refusal,
  completion_review_refusal = completion_review_refusal,
  research_landing_refusal = research_landing_refusal,
  product_landing_refusal = product_landing_refusal,
  undeclared_repos = undeclared_repos,
  readiness_issues = readiness_issues,
}
return M
