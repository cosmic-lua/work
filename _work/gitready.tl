--- The spec bar's PR-handover half: whether a pull request is worth a
--- reviewer's time (`handover_refusal`), the one-PR-one-item rule
--- (`pr_collision_refusal`), the undeclared-read-access check
--- (`undeclared_repos`), and the full list of problems a `take`
--- enforces (`ready_problems`). Split from `_work.gitgate`, which
--- sits against the file cap; the identity, force and claim-lease
--- refusals stay there.
local flow = require("_work.flow")
local gh = require("_work.gh")
local item = require("_work.item")
local owner = require("_work.gitowner")
local publish = require("_work.publish")
local rank = require("_work.rank")
local review = require("_work.review")
local spec = require("_work.spec")
local store = require("_work.store")

--- The refusal a PR handover earns from GitHub, or nil when the
--- request is worth a reviewer's time: open, not a draft, joined
--- to its item by a `Board:` line, targeting the item's own `base`
--- when it names one, and not already known to fail CI.
---
--- A missing token is itself a refusal rather than a silent pass —
--- a gate that waves things through when it cannot see is worse than
--- no gate — and `--force` is the way past it, exactly as with every
--- other refusal here.
--- @param s store.Store The store
--- @param id string The item being handed over
--- @param number integer The PR number
--- @param repo string | nil The item's repo field, when it carries one
--- @param base string | nil The item's base field, when it carries one
--- @return string | nil The refusal
local function handover_refusal(s: store.Store, id: string,
    number: integer, repo: string | nil, base: string | nil): string
  -- A local-only board has no pull requests to ask about, the same
  -- reason publishing there is a no-op.
  if not publish.has_origin(s) then
    return nil
  end
  local p, perr = gh.pull(s, number, repo)
  if p == nil then
    return ("cannot read PR #%d: %s; --force to hand it over anyway"):format(
      number, perr)
  end
  local blocked = review.blocks_check(p, id)
  if blocked then
    return blocked
  end
  local off_base = review.blocks_base(p, base or "")
  if off_base then
    return off_base
  end
  local runs, cerr = gh.checks(s, p.head_sha, repo)
  if runs == nil then
    return ("cannot read CI for %s: %s; --force to hand it over anyway")
    :format(p.head_sha:sub(1, 7), cerr)
  end
  return review.blocks_on_ci(runs)
end

--- The refusal a PR handover earns when another OPEN item already
--- records the same number, or nil when it is free to take. One pull
--- request couples one item's verdict, so recording a number an open
--- item already holds would let a single diff answer for two — a DONE
--- item's PR is spent and names nothing.
--- @param all {item.Item} Every item
--- @param id string The item recording the PR
--- @param number integer The PR number being recorded
--- @return string | nil The refusal
local function pr_collision_refusal(all: {item.Item}, id: string,
    number: integer): string | nil
  for _, other in ipairs(all) do
    if other.id ~= id and item.is_open(other) and (other.pr or 0) == number then
      return ("PR #%d is already %s's — one PR, one item; --force --why "
        .. "to override for repair"):format(number, other.id:sub(1, 8))
    end
  end
  return nil
end

--- The repositories a spec reaches (`spec.reached_repos`) that are
--- neither the item's own `repo` field nor declared under its
--- `## Access` heading (`spec.declared_repos`) — an undeclared source
--- strands a claim before it starts and a review just as surely,
--- since neither session's grant is anything this board can see. The
--- item's own `repo` is the one exemption that needs no declaring: it
--- is where the diff lands, not a source read on the side.
--- @param it item.Item The item
--- @param body string Its spec sidecar
--- @return {string} Undeclared repo slugs, in first-seen order
local function undeclared_repos(it: item.Item, body: string): {string}
  local declared = spec.declared_repos(body)
  local own = (it.repo or ""):lower()
  local out: {string} = {}
  for _, repo in ipairs(spec.reached_repos(body)) do
    if repo ~= own and not declared[repo] then
      out[#out + 1] = repo
    end
  end
  return out
end

--- The problems that keep an item from being taken: it must be
--- workable, its outcome must be ranked, its spec must fill the
--- spec-bar sections, its own chain must be traceable, and its
--- `repo` must be somewhere a claiming session can land a diff. The
--- one list `check` reports and `take` enforces.
--- @param s store.Store The store
--- @param it item.Item The item
--- @param all {item.Item} Every item
--- @param body string | nil Its spec sidecar, when the caller already
--- has it (a batched `read_specs`, say) — nil to read it here
--- @return {string} Problems, empty when the item meets the bar
local function ready_problems(s: store.Store, it: item.Item,
    all: {item.Item}, body?: string): {string}
  local index = flow.by_id(all)
  local out = flow.item_problems(it, index)
  local r = flow.role(it, all)
  if r ~= "work" then
    out[#out + 1] = ("%s is a %s, not workable"):format(it.id:sub(1, 8), r)
  end
  -- Rank is a path from the outcome: an item whose outcome is not in
  -- the board's own `order` has no answer to "where does this sit
  -- against everything else" and cannot be queued honestly.
  if not rank.is_ranked(rank.positions(all), it.id) then
    out[#out + 1] = ("%s's outcome is unranked — rank the outcome first "
      .. "(`gitboard rank <outcome>`), or attach it under an item that "
      .. "already is"):format(it.id:sub(1, 8))
  end
  local spec_body = body or store.read_spec(s, it.id)
  for _, gap in ipairs(flow.ready_gaps(spec_body)) do
    out[#out + 1] = ("spec: %s"):format(gap)
  end
  for _, repo in ipairs(undeclared_repos(it, spec_body)) do
    out[#out + 1] = ("spec reaches %s with no declared read access — name "
      .. "it under \"## Access\"; undeclared, it strands the claim now "
      .. "and the review just as surely"):format(repo)
  end
  -- The item's own `repo` is exempt above because it is where the diff
  -- lands — which is exactly why it must be somewhere the claiming
  -- session can land one (`_work.gitowner`).
  local foreign = owner.repo_problem(s, it.repo, spec_body, it.id)
  if foreign then
    out[#out + 1] = foreign
  end
  return out
end

local record gitready
  handover_refusal: function(s: store.Store, id: string,
  number: integer, repo: string | nil, base: string | nil): string
  pr_collision_refusal: function(all: {item.Item}, id: string,
  number: integer): string
  undeclared_repos: function(it: item.Item, body: string): {string}
  ready_problems: function(s: store.Store, it: item.Item,
  all: {item.Item}, body?: string): {string}
end

local M: gitready = {
  handover_refusal = handover_refusal,
  pr_collision_refusal = pr_collision_refusal,
  undeclared_repos = undeclared_repos,
  ready_problems = ready_problems,
}

return M
