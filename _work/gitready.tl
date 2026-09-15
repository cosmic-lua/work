--- The spec bar's PR-handover half: whether a pull request is worth a
--- reviewer's time (`handover_refusal`), the one-PR-one-item rule
--- (`pr_collision_refusal`), the undeclared-read-access check
--- shared spec/access checks, the unresolved dependencies that keep an item
--- from starting, and the full list of problems a `take`
--- enforces (`ready_problems`). Split from `_work.gitgate`, which
--- sits against the file cap; the identity, force and claim-lease
--- refusals stay there.
local item = require("_work.item")
local itemtree = require("_work.itemtree")
local read = require("_work.read")
local store = require("_work.store")
local tail = require("_work.tail")
local workflow_rules = require("_work.workflow_rules")

--- Compatibility refusal for the removed provider-shaped PR handover.
--- Gitboard's authoritative handover fact is now only a locally present
--- product commit. The caller may create or inspect a pull request using any
--- authenticated tooling, then records that commit with `take --head SHA`.
--- @param s store.Store The store
--- @param id string The item being handed over
--- @param number integer The PR number
--- @param repo string | nil The item's repo field, when it carries one
--- @param base string | nil The item's base field, when it carries one
--- @return string | nil The refusal
local function handover_refusal(_s: store.Store, _id: string,
    number: integer, _repo: string | nil, _base: string | nil): string
  return ("PR #%d is navigation, not evidence; use take ID --head SHA "
    .. "[--url URL] after inspecting it with caller-owned tooling"):format(number)
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

--- The problems that keep an item from being taken: it must be
--- workable, its outcome must be ranked, its spec must fill the
--- spec-bar sections, its own chain must be traceable, and its
--- `repo` must be somewhere a claiming session can land a diff. The
--- one list `check` reports and `take` enforces.
--- @param s store.Store The store
--- @param it item.Item The item
--- @param prose itemtree.Spec | nil Its two spec blobs, when the caller
--- already has them (a batched `read_specs`, say) — nil to read them here
--- @return {string} Problems, empty when the item meets the bar
local function ready_problems(s: store.Store, it: item.Item,
    prose?: itemtree.Spec): {string}
  local out: {string} = {}
  local c, cerr = store.read(s)
  if c == nil then
    out[#out + 1] = ("could not read the board database: %s"):format(cerr)
    return out
  end
  local structure, sterr = read.structure(c)
  if structure == nil then
    out[#out + 1] = ("could not read board structure: %s"):format(sterr)
  else
    for _, row in ipairs(structure) do
      if row.id == it.id and (row.kind == "dangling_parent" or row.kind == "deep_chain") then
        out[#out + 1] = ("%s: %s"):format(it.id:sub(1, 8), row.detail)
      end
    end
  end
  local r, rerr = read.role(c, it.id)
  if r == nil then
    out[#out + 1] = ("could not read role: %s"):format(rerr)
  elseif r ~= "work" then
    out[#out + 1] = ("%s is a %s, not workable"):format(it.id:sub(1, 8), r)
  end
  -- Rank is a path from the outcome: an item whose outcome is not in
  -- the board's own `order` has no answer to "where does this sit
  -- against everything else" and cannot be queued honestly.
  local ranked, rkerr = read.is_ranked(c, it.id)
  if ranked == nil then
    out[#out + 1] = ("could not read rank: %s"):format(rkerr)
  elseif not ranked then
    out[#out + 1] = ("%s's outcome is unranked — rank the outcome first "
      .. "(`gitboard rank <outcome>`), or attach it under an item that "
      .. "already is"):format(it.id:sub(1, 8))
  end
  -- Every declared dependency that is not yet done, named: a blocked
  -- item that simply failed to appear would read as a bug rather than
  -- as a queue waiting on something. Each dependency is loaded on its
  -- own rather than off a whole-board list, because `depends_on` is
  -- empty on almost every item and this loop then costs nothing.
  for _, dep in ipairs(it.depends_on or {}) do
    local blocker, _derr = store.load(s, dep)
    if blocker == nil then
      out[#out + 1] = ("depends on %s (not on the board), which is not done "
        .. "yet"):format(tail.handle(dep))
    elseif item.is_open(blocker) then
      out[#out + 1] = ("depends on %s (%s), which is not done yet"):format(
        tail.handle(dep), blocker.title)
    end
  end
  local sp = prose or store.read_spec(s, it.id)
  for _, issue in ipairs(workflow_rules.readiness_issues(it, sp)) do
    local repo = issue:match("^undeclared repository (.+)$")
    if repo == nil then out[#out + 1] = issue:gsub("^spec ", "spec: ")
    else
      out[#out + 1] = ("spec reaches %s with no declared read access — "
        .. "declare it (`gitboard set %s --access %s`); undeclared, it "
        .. "strands the claim now and the review just as surely"):format(
        repo, it.id:sub(1, 8), repo)
    end
  end
  return out
end

local record gitready
  handover_refusal: function(s: store.Store, id: string,
  number: integer, repo: string | nil, base: string | nil): string
  pr_collision_refusal: function(all: {item.Item}, id: string,
  number: integer): string
  ready_problems: function(s: store.Store, it: item.Item,
  prose?: itemtree.Spec): {string}
end

local M: gitready = {
  handover_refusal = handover_refusal,
  pr_collision_refusal = pr_collision_refusal,
  ready_problems = ready_problems,
}

return M
