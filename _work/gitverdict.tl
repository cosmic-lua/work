--- Provider-neutral review verdicts. Gitboard neither reads nor writes a
--- forge: the caller inspects checks externally and names the exact product
--- commit it judged. The only durable evidence is that commit id.
local commit_evidence = require("_work.commit_evidence")
local gate = require("_work.gitgate")
local ghland = require("_work.ghland")
local item = require("_work.item")
local repository_map = require("_work.repository_map")
local store = require("_work.store")

local KIND_ALIASES: {string: string} = {
  ["request-changes"] = "request changes",
  ["rework"] = "request changes",
}

local KINDS: {string: boolean} = {
  ["accept"] = true,
  ["request changes"] = true,
  ["reject"] = true,
}

local function already_judged_refusal(id: string, head: string): string
  return ("%s's commit %s was already given this verdict — hand over a new "
    .. "commit before judging again"):format(id:sub(1, 8), head:sub(1, 12))
end

--- The research counterpart of `commit_evidence.verify_lineage`, run in
--- the BOARD checkout. A research review judges `result` — the board
--- commit `take ID --result` recorded, the item ref's tip as it stood —
--- so the sha the caller names must equal it exactly, and it must still
--- sit in that ref's history: the same ancestry `verify_lineage` asks of
--- a product commit against its claim base, with `result` as the base
--- and the tip the store leased for this item as the head. The product
--- checkout is never consulted; it could not resolve a board commit.
--- `done` applies the same check to the `--landed` commit that closes an
--- accepted research item, which is why it is exported.
--- @param s store.Store The store, its lease on `it` taken by a load or list
--- @param it item.Item The item, `result` set
--- @param given string The commit the caller named
--- @return string | nil The canonical board commit
--- @return string Error message
local function verify_result(s: store.Store, it: item.Item,
    given: string): string | nil, string
  local id8 = it.id:sub(1, 8)
  local result = it.result or ""
  if given ~= result then
    return nil, ("%s's research handover is %s, not %s — a research head is "
      .. "named exactly"):format(id8, result, given)
  end
  local tip = s.leased_sha[it.id] or ""
  if tip == "" then
    return nil, ("%s has no observed board commit — read the board first")
    :format(id8)
  end
  local lineage, lerr = commit_evidence.verify_lineage(s.root, result, tip)
  if lineage == nil then
    return nil, ("%s's research result %s is not a commit on its own ref: %s")
    :format(id8, result:sub(1, 12), lerr)
  end
  return lineage.base, ""
end

--- Record a verdict over one locally inspectable product commit. The reviewer
--- must hold the current whole-item claim and must be independent of the
--- builder/speccer unless an audited repair says otherwise. Review acquisition
--- is therefore explicit: builder handover, builder drop, reviewer claim.
--- Verdict never releases the reviewer's claim.
---
--- An accept records first and only then attempts a landing, and only
--- when the caller has activated provider transport (`_work.ghland`).
--- Landing is off by default: with no activation, or no pull request
--- recorded on the item, nothing is written anywhere but the board and
--- the caller lands the work itself, exactly as before. A landing that
--- is attempted and fails is reported on the verdict line; it never
--- refuses the verb, which would throw away a judgment that is already
--- true.
--- @param send ghland.Transport | nil What an activated landing performs
--- its requests with (defaults to `cosmic.fetch.fetch`); a test passes a
--- capture instead
local function cmd_verdict_commit(s: store.Store, id: string, kind: string,
    head: string, session: string, force: boolean, why: string,
    repo_dir: string, send?: ghland.Transport): integer
  local forced = gate.force_refusal(force, why)
  if forced then
    return gate.verdict_line("verdict", false, "REFUSED: " .. forced)
  end
  local bad_session = item.identity_refusal(session)
  if bad_session then
    return gate.verdict_line("verdict", false, "REFUSED: " .. bad_session)
  end
  kind = KIND_ALIASES[kind] or kind
  if not KINDS[kind] then
    return gate.verdict_line("verdict", false,
      ("unknown verdict: %s"):format(kind))
  end
  local it, ierr = store.load(s, id)
  if it == nil then return gate.verdict_line("verdict", false, ierr) end
  if not force then
    local distance = gate.distance_refusal(it, session)
    if distance then return gate.verdict_line("verdict", false, distance) end
  end
  if (it.claim or "") ~= session then
    return gate.verdict_line("verdict", false,
      ("REFUSED: %s's verdict belongs to its claim holder"):format(id:sub(1, 8)))
  end
  -- The commit a review judges follows the item's deliverable, as `brief
  -- review` renders it: a diff hands over a product commit
  -- (`handover_head`, verified in the product checkout against the claim
  -- base), research hands over board state (`result`, verified in the
  -- board checkout against the item's own ref). With both recorded the
  -- product commit is the handover, as `take --head` itself decides.
  local handed = it.handover_head or ""
  local result = it.result or ""
  local canonical = ""
  if handed ~= "" then
    local claim_base = it.claim_base or ""
    if claim_base == "" then
      return gate.verdict_line("verdict", false,
        ("REFUSED: %s's claim has no product base commit"):format(id:sub(1, 8)))
    end
    local root, rerr = repository_map.resolve(s.root, it.repo or "", repo_dir)
    if root == nil then
      return gate.verdict_line("verdict", false, "REFUSED: " .. rerr)
    end
    local lineage, verr = commit_evidence.verify_lineage(root, claim_base, head)
    if lineage == nil then
      return gate.verdict_line("verdict", false, "REFUSED: " .. verr)
    end
    canonical = lineage.head
    if canonical ~= handed then
      return gate.verdict_line("verdict", false,
        ("REFUSED: verdict names %s, but the handover is %s")
        :format(canonical, handed))
    end
  elseif result ~= "" then
    local judged, jerr = verify_result(s, it, head)
    if judged == nil then
      return gate.verdict_line("verdict", false, "REFUSED: " .. jerr)
    end
    canonical = judged
  else
    return gate.verdict_line("verdict", false,
      ("REFUSED: %s has no commit handover to judge"):format(id:sub(1, 8)))
  end
  if (it.verdict_head or "") == canonical and (it.verdict or "") == kind then
    return gate.verdict_line("verdict", false,
      "REFUSED: " .. already_judged_refusal(id, canonical))
  end
  if it.verdict == "accept" then
    return gate.verdict_line("verdict", false,
      ("REFUSED: %s already carries an accept — complete it")
      :format(id:sub(1, 8)))
  end

  it.verdict_head = canonical
  if kind == "reject" then
    -- The rejected handover no longer stands, but the claim does. Its holder
    -- explicitly drops or renews; no workflow transition releases it. A
    -- research handover is cleared the same way, so the item reads as
    -- mid-flight again and the next `take --result` is a new handover,
    -- never the no-op an unmoved spec would otherwise be.
    it.verdict = ""
    it.handover_head = ""
    it.result = ""
    it.external_url = ""
  else
    it.verdict = kind
  end
  local by = session == "" and "" or (" by %s"):format(session)
  local ok, err = gate.commit_and_publish(s, it, nil,
    ("verdict %s %s head:%s%s%s"):format(id:sub(1, 8), kind,
      canonical:sub(1, 12), by, gate.forced_suffix(force, why)),
    "verdict", nil, session, false, force, why)
  if not ok then return gate.verdict_line("verdict", false, err) end
  local landed = ""
  if kind == "accept" then
    landed = ghland.note(ghland.land(s, it, canonical, send))
  end
  return gate.verdict_line("verdict", true,
    ("%s on %s at %s: recorded%s"):format(
      kind, id:sub(1, 8), canonical:sub(1, 12), landed))
end

--- One-release compatibility surface for pre-v3 callers. It performs no
--- provider read or write and cannot mutate the board.
local function cmd_verdict(_s: store.Store, _id: string, _kind: string,
    _pr: integer, _head: string, _session?: string, _force?: boolean,
    _why?: string, _body_file?: string, _no_land?: boolean): integer
  return gate.verdict_line("verdict", false,
    "REFUSED: legacy PR verdict is disabled — inspect checks externally "
    .. "and run `gitboard verdict ID KIND --head SHA`")
end

local record gitverdict
  cmd_verdict_commit: function(s: store.Store, id: string, kind: string,
  head: string, session: string, force: boolean, why: string,
  repo_dir: string, send?: ghland.Transport): integer
  cmd_verdict: function(s: store.Store, id: string, kind: string,
  pr: integer, head: string, session?: string, force?: boolean,
  why?: string, body_file?: string, no_land?: boolean): integer
  already_judged_refusal: function(id: string, head: string): string
  verify_result: function(s: store.Store, it: item.Item,
  given: string): string | nil, string
end

local M: gitverdict = {
  cmd_verdict_commit = cmd_verdict_commit,
  cmd_verdict = cmd_verdict,
  already_judged_refusal = already_judged_refusal,
  verify_result = verify_result,
}

return M
