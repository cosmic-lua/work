--- Mandatory parent-to-final-board validation and compact publication preflight.
local boardread = require("_work.boardread")
local claim = require("_work.claim")
local commit_evidence = require("_work.commit_evidence")
local index = require("_work.index")
local item = require("_work.item")
local read = require("_work.read")
local snapshot = require("_work.snapshot")
local stateclaim = require("_work.stateclaim")
local stateread_fsck = require("_work.stateread_fsck")
local stategate = require("_work.stategate")
local projection = require("_work.stateplan_git")
local repository_map = require("_work.repository_map")
local stateevidence = require("_work.stateevidence")
local tx = require("_work.statetransaction")
local workflow_rules = require("_work.workflow_rules")

local record Changed
  id: string
  status: string
end
local record Report
  changed: {Changed}
  existing_issues: {string}
  new_issues: {string}
  publish_by: integer
  before: boardread.View
  after: boardread.View
  item_ids: {string: boolean}
  claim_ids: {string: boolean}
  identity: snapshot.Identity
  changes: {tx.Change}
end

local function forced(message: string): boolean
  return message:find("%(forced:%s*%S", 1, false) ~= nil
  or message:find("\nForce%-Why:%s*%S", 1, false) ~= nil
end

local function status(view: boardread.View, derived: index.Index,
    id: string): string | nil, string
  local it = view.items_by_id[id]
  if it == nil then return "removed", "" end
  local current, err = read.state(derived, id)
  if current == nil then return nil, err end
  if current ~= "doing" then return current, "" end
  return read.substate(derived, id)
end

local function issue_set(view: boardread.View, board_id: string): {string: boolean}
  local out: {string: boolean} = {}
  for _, it in ipairs(view.items) do
    if it.id ~= board_id then
      for _, issue in ipairs(workflow_rules.readiness_issues(it,
          view.specs_by_id[it.id])) do
        out[it.id .. ": " .. issue] = true
      end
    end
  end
  return out
end

local function min_deadline(current: integer, value: integer): integer
  if value <= 0 then return current end
  if current == 0 or value < current then return value end
  return current
end

local function appended(old: {string}, new: {string}): boolean
  if #new < #old then return false end
  for i, value in ipairs(old) do
    if new[i] ~= value then return false end
  end
  return true
end

local function claim_rules(before: boardread.View, after: boardread.View,
    ids: {string: boolean}, author: string, message: string, now: integer): integer | nil, string
  local deadline = 0
  local repair = forced(message)
  for id in pairs(ids) do
    local old, new = before.claims_by_id[id], after.claims_by_id[id]
    if new == nil then
      if old == nil then return nil, "claim deletion has no canonical claim: " .. id end
      local refusal = claim.drop_refusal(stateclaim.state(old), author, now,
        repair, repair and message or "")
      if refusal ~= nil then return nil, refusal .. ": " .. id end
    elseif old == nil or old.id ~= new.id then
      -- Acquisition never supersedes a live claim, even with repair syntax,
      -- and an active holder must use renew or drop instead of rotating the
      -- claim identity or product base.
      local refusal, held = claim.take_refusal(stateclaim.state(old), author,
        now, false, "")
      if held then
        refusal = "item is already claimed by this session; use renew or drop"
      end
      if refusal ~= nil then return nil, refusal .. ": " .. id end
      local shape = workflow_rules.claim_acquisition_refusal(new, author, now)
      if shape ~= nil then return nil, shape .. ": " .. id end
      deadline = min_deadline(deadline, new.expires_at)
    else
      local refusal = claim.renew_refusal(stateclaim.state(old), author, now)
      if refusal ~= nil then return nil, refusal .. ": " .. id end
      local shape = workflow_rules.claim_renewal_refusal(old, new)
      if shape ~= nil then return nil, shape .. ": " .. id end
      deadline = min_deadline(deadline, old.expires_at)
    end
  end
  return deadline, ""
end

--- Reproduce boardread's clock-sensitive claim projection without reading the
--- trees again. A proposal must remain decodable at its logical author time,
--- because recovery reconstructs the frozen plan at that instant.
local function claim_clock_refusal(view: boardread.View,
    now: integer): string | nil
  for _, it in ipairs(view.items) do
    local lease = view.claims_by_id[it.id]
    if lease ~= nil and lease.renewed_at > now + claim.FUTURE_SKEW_S then
      return "claim for " .. it.id .. " is more than five minutes in the future"
    end
  end
  return nil
end

local function authority_rules(before: boardread.View, after: boardread.View,
    item_ids: {string: boolean}, claim_ids: {string: boolean}, author: string,
    message: string, now: integer): integer | nil, string
  local deadline, cerr = claim_rules(before, after, claim_ids,
    author, message, now)
  if deadline == nil then return nil, cerr end
  local repair = forced(message)
  for id in pairs(item_ids) do
    local lease = before.claims_by_id[id]
    local refusal = claim.mutation_refusal(stateclaim.state(lease), author,
      now, repair, repair and message or "")
    if refusal ~= nil then return nil, refusal .. ": " .. id end
    if lease ~= nil and lease.holder == author then
      deadline = min_deadline(deadline, lease.expires_at)
    end
  end
  if deadline > 0 and now >= deadline then
    return nil, "prepared claim expired before publication"
  end
  return deadline, ""
end

local function recheck(report: Report, author: string, message: string,
    now?: integer): integer | nil, string
  local clock = now or os.time()
  local refusal = claim_clock_refusal(report.before, clock)
  or claim_clock_refusal(report.after, clock)
  if refusal ~= nil then return nil, refusal end
  return authority_rules(report.before, report.after, report.item_ids,
    report.claim_ids, author, message, clock)
end

local function semantic_gates(root: string, parent: string, changes: {tx.Change},
    before: boardread.View, after: boardread.View, ids: {string: boolean},
    author: string, repair: boolean): boolean, string
  local needs: {string: boolean} = {}
  local old_root, new_root = "", ""
  for _, it in ipairs(before.items) do
    if item.is_parentless(it) then
      if old_root ~= "" then return false, "canonical board has multiple parentless items" end
      old_root = it.id
    end
  end
  for _, it in ipairs(after.items) do
    if item.is_parentless(it) then
      if new_root ~= "" then return false, "snapshot creates a second parentless item" end
      new_root = it.id
    end
  end
  if old_root == "" or new_root ~= old_root then
    return false, "snapshot changes the canonical board root"
  end
  for id in pairs(ids) do
    local old, new = before.items_by_id[id], after.items_by_id[id]
    if old == nil then needs.new = true end
    if new ~= nil then
      local handover_changed = old == nil and ((new.handover_head or "") ~= ""
        or (new.result or "") ~= "") or old ~= nil and
      (old.handover_head ~= new.handover_head or old.result ~= new.result)
      local verdict_changed = old == nil and ((new.verdict or "") ~= ""
        or (new.verdict_head or "") ~= "") or old ~= nil and
      (old.verdict ~= new.verdict or old.verdict_head ~= new.verdict_head)
      local landing_changed = old == nil and ((new.resolution or "") ~= ""
        or (new.landed_head or "") ~= "") or old ~= nil and
      (old.resolution ~= new.resolution or old.landed_head ~= new.landed_head)
      if old == nil and (handover_changed or verdict_changed or landing_changed) then
        return false, "new item carries workflow evidence: " .. id
      end
      if old == nil then
        needs.attach = true
        if #(new.depends_on or {}) > 0 then needs.depend = true end
      end
      if old ~= nil and (not appended(old.builders or {}, new.builders or {})
        or not appended(old.speccers or {}, new.speccers or {})) then
        return false, "workflow attribution is append-only: " .. id
      end
      local old_spec = before.specs_by_id[id]
      or {change = "", non_goals = ""}
      local new_spec = after.specs_by_id[id]
      or {change = "", non_goals = ""}
      local spec_changed = old_spec.change ~= new_spec.change
      or old_spec.non_goals ~= new_spec.non_goals
      if spec_changed and author ~= "gitboard" then
        local refusal = workflow_rules.attribution_refusal(new.speccers or {},
          author, "spec change lacks author attribution")
        if refusal ~= nil then return false, refusal .. ": " .. id end
      end
      if old ~= nil and old.verdict == "accept" and verdict_changed then
        local new_product_handover = (new.handover_head or "") ~= ""
        and (new.verdict or "") == "" and (new.verdict_head or "") == ""
        and (handover_changed and new.handover_head ~= old.handover_head
          or old.handover_head == new.handover_head
          and old.verdict_head ~= new.handover_head)
        if not new_product_handover then
          return false, "accepted verdict cannot be changed: " .. id
        end
      end
      if old ~= nil and old.parent ~= new.parent then needs.attach = true end
      if old ~= nil and table.concat(old.depends_on or {}, "\0") ~=
      table.concat(new.depends_on or {}, "\0") then needs.depend = true end
      if landing_changed and new.resolution ~= "" then needs.done = true end
      if handover_changed and (new.handover_head or "") == ""
      and (new.result or "") == "" and not verdict_changed and not repair then
        return false, "handover evidence removed without a verdict: " .. id
      end
      if handover_changed and ((new.handover_head or "") ~= ""
        or (new.result or "") ~= "") then
        local lease = before.claims_by_id[id]
        if lease == nil or new.claim ~= author or new.claim_base ~= lease.product_base
        or new.claim_batch ~= lease.id then
          return false, "handover lacks canonical claim evidence: " .. id
        end
        local refusal = workflow_rules.attribution_refusal(new.builders or {},
          author, "handover lacks builder attribution")
        if refusal ~= nil then return false, refusal .. ": " .. id end
      end
      if handover_changed and (new.handover_head or "") ~= "" and not repair then
        local product, rerr = repository_map.resolve(root, new.repo or "", "")
        if product == nil then return false, "cannot verify handover: " .. rerr end
        local lineage, lerr = commit_evidence.verify_lineage(product,
          new.claim_base or "", new.handover_head or "")
        if lineage == nil then return false, "invalid handover evidence: " .. lerr end
      end
      if handover_changed and (new.result or "") ~= "" and not repair then
        local evidence, eerr = stateevidence.verify(root, parent, new.result or "", id)
        if evidence == nil then return false, "invalid research evidence: " .. eerr end
      end
      if verdict_changed and (new.verdict or "") ~= ""
      and (new.verdict_head or "") == "" then
        return false, "verdict lacks current handover evidence: " .. id
      end
      if verdict_changed and (new.verdict_head or "") ~= "" then
        local lease = before.claims_by_id[id]
        if lease == nil or (old.claim or "") ~= author
        or lease.holder ~= author then
          return false, "verdict belongs to canonical claim holder: " .. id
        end
        local evidence_item = new
        local current_evidence = workflow_rules.handover_evidence(evidence_item)
        if current_evidence == "" and old ~= nil then evidence_item = old end
        if not repair then
          local distance = workflow_rules.distance_refusal(new, author)
          if distance ~= nil then return false, distance end
          local function resolve_evidence(current: item.Item, kind: string,
              named: string): string | nil, string
            if kind == "product" then
              local product, rerr = repository_map.resolve(root,
                current.repo or "", "")
              if product == nil then return nil, "cannot verify verdict: " .. rerr end
              local lineage, lerr = commit_evidence.verify_lineage(product,
                current.claim_base or "", named)
              if lineage == nil then return nil, "invalid verdict evidence: " .. lerr end
              return lineage.head, ""
            end
            local verified, eerr = stateevidence.verify(root, parent, named, id)
            if verified == nil then return nil, "invalid verdict evidence: " .. eerr end
            return named, ""
          end
          local verified, verr = workflow_rules.verdict_evidence(evidence_item,
            new.verdict_head or "", resolve_evidence,
            "verdict does not name current handover evidence: " .. id)
          if verified == nil then return false, verr end
        else
          local evidence = workflow_rules.handover_evidence(evidence_item)
          if (new.verdict_head or "") ~= evidence then
            return false, "verdict does not name current handover evidence: " .. id
          end
        end
      end
      if handover_changed and (new.result or "") ~= "" then
        local spec_refusal = workflow_rules.research_spec_refusal(id,
          after.specs_by_id[id])
        if spec_refusal ~= nil then return false, spec_refusal end
      end
      if landing_changed and new.resolution == "completed" then
        local review_refusal = workflow_rules.completion_review_refusal(new, repair)
        if review_refusal ~= nil then return false, review_refusal end
      end
      if landing_changed and new.resolution == "completed"
      and not repair and (new.handover_head or "") ~= "" then
        local shape = workflow_rules.product_landing_refusal(new, "completed",
          new.landed_head or "", false)
        if shape ~= nil then return false, shape .. ": " .. id end
        local product, rerr = repository_map.resolve(root, new.repo or "", "")
        if product == nil then return false, "cannot verify landing: " .. rerr end
        local landed, lerr = commit_evidence.verify_landing(product,
          new.claim_base or "", new.verdict_head or "", new.landed_head or "")
        if landed == nil then return false, "invalid landed evidence: " .. lerr end
      end
      if landing_changed and new.resolution == "completed"
      and (new.handover_head or "") == "" and (new.result or "") ~= "" then
        local landing_refusal = workflow_rules.research_landing_refusal(new,
          "completed", new.landed_head or "", repair)
        if landing_refusal ~= nil then return false, landing_refusal .. ": " .. id end
        local verified, eerr = stateevidence.verify(root, parent,
          new.result or "", id)
        if verified == nil then return false, "invalid research landing evidence: " .. eerr end
        if repair and (new.landed_head or "") ~= ""
        and new.landed_head ~= new.result then
          local resolved, rerr = commit_evidence.commit_id(root,
            new.landed_head or "")
          if resolved == nil then return false, "invalid repaired research landing: " .. rerr end
        end
      end
      if landing_changed and new.resolution == "completed" then
        local children = workflow_rules.child_state(after.items, id)
        if children.any and not children.completed then
          return false, "completed outcome lacks completed child evidence: " .. id
        end
      end
    end
  end
  for gate in pairs(needs) do
    local transition: tx.Transition = {base = parent, dependencies = {}, changes = changes,
      message = "snapshot validation", author = {name = "validator", email = "validator@board", date = "1 +0000"},
      publish_by = 0, bounded = true, gate = gate}
    local ok, err = stategate.check_views(before, after, transition)
    if not ok then return false, err end
  end
  return true, ""
end

local function preflight(root: string, parent: string, commit: string,
    now?: integer): Report | nil, string
  local clock = now or os.time()
  local identity, ierr = snapshot.commit_identity(root, commit)
  if identity == nil then return nil, ierr end
  if identity.parent ~= parent then return nil, "snapshot parent differs" end
  local before, berr = boardread.list(root, parent, clock)
  if before == nil then return nil, berr end
  local after, aerr = boardread.list(root, commit, clock)
  if after == nil then return nil, aerr end
  local observed, oerr = projection.capture(root, parent, commit, {})
  if observed == nil then return nil, oerr end
  local item_ids: {string: boolean} = {}
  local claim_ids: {string: boolean} = {}
  for _, change in ipairs(observed.changes) do
    local iid = change.path:match("^items/([^/]+)/")
    local cid = change.path:match("^claims/([^/]+)$")
    if iid ~= nil then item_ids[iid] = true end
    if cid ~= nil then claim_ids[cid] = true end
    if change.path:match("^migration/") then
      return nil, "immutable migration evidence changed: " .. change.path
    end
    if iid == nil and cid == nil and change.path ~= "format" then
      return nil, "snapshot changes undeclared board path: " .. change.path
    end
  end
  local problems = stateread_fsck.view_problems(root, commit, after)
  if #problems > 0 then return nil, "invalid final board: " .. table.concat(problems, "; ") end
  if next(item_ids) ~= nil and next(claim_ids) ~= nil then
    return nil, "claim acquisition/release is a separate publication boundary"
  end
  local deadline, cerr = authority_rules(before, after, item_ids, claim_ids,
    identity.author.name, identity.message, clock)
  if deadline == nil then return nil, cerr end
  local authored, authored_err = snapshot.author_time(identity.author)
  if authored == nil then return nil, authored_err end
  if authored ~= clock then
    local historical_refusal = claim_clock_refusal(before, authored)
    or claim_clock_refusal(after, authored)
    if historical_refusal ~= nil then return nil, historical_refusal end
    local historical, herr = authority_rules(before, after, item_ids,
      claim_ids, identity.author.name, identity.message, authored)
    if historical == nil then return nil, herr end
  end
  local repair = forced(identity.message)
  local gates, gerr = semantic_gates(root, parent, observed.changes, before, after,
    item_ids, identity.author.name, repair)
  if not gates then return nil, gerr end
  local board_id = ""
  for _, it in ipairs(before.items) do
    if item.is_parentless(it) then board_id = it.id; break end
  end
  local prior, final = issue_set(before, board_id), issue_set(after, board_id)
  local report: Report = {changed = {}, existing_issues = {}, new_issues = {},
    publish_by = deadline, before = before, after = after,
    item_ids = item_ids, claim_ids = claim_ids, identity = identity,
    changes = observed.changes}
  local derived, derr = index.open(after.items)
  if derived == nil then return nil, derr end
  for id in pairs(item_ids) do
    local lifecycle, lerr = status(after, derived, id)
    if lifecycle == nil then local _ok, _err = index.close(derived); return nil, lerr end
    report.changed[#report.changed + 1] = {id = id, status = lifecycle}
  end
  for id in pairs(claim_ids) do if not item_ids[id] then
      local lifecycle, lerr = status(after, derived, id)
      if lifecycle == nil then local _ok, _err = index.close(derived); return nil, lerr end
      report.changed[#report.changed + 1] = {id = id, status = lifecycle}
    end end
  local closed, close_err = index.close(derived)
  if not closed then return nil, close_err end
  table.sort(report.changed, function(a: Changed, b: Changed): boolean return a.id < b.id end)
  for issue in pairs(final) do
    if prior[issue] then report.existing_issues[#report.existing_issues + 1] = issue
    else report.new_issues[#report.new_issues + 1] = issue end
  end
  table.sort(report.existing_issues); table.sort(report.new_issues)
  return report, ""
end

local record Module
  type Changed = Changed
  type Report = Report
  preflight: function(string, string, string, integer | nil): Report | nil, string
  recheck: function(Report, string, string, integer | nil): integer | nil, string
end
local M: Module = {preflight = preflight, recheck = recheck}
return M
