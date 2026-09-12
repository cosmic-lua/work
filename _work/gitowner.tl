--- The owner rule an item's `repo` field meets: the repository a diff
--- lands in must share the board's own GitHub owner, or the spec must
--- declare it as read access. A claiming session is granted the
--- board's repositories and nothing this board can see beyond them,
--- so a `repo` under a foreign owner — a personal fork's name left
--- over from when the evidence was gathered, most often — strands the
--- claim before it starts. The owner is the proxy the board CAN
--- check; the access declaration is the deliberate cross-owner case.
---
--- That declaration is MID-MOVE, and this comment is the window's
--- record. It was a `## Access` section, and this rule still reads
--- one — every unmigrated `spec.md` reads back as prose carrying it,
--- which is most of the board. But `_work.spec`'s `split` refuses the
--- section on a WRITE now, because format 5 makes access a declared
--- field, and the flag that sets that field is its own change. So
--- there is a window in which a newly written spec cannot declare
--- access at all, and the refusal below names only the FACT — not the
--- section a write refuses, and not a flag this build does not have.
---
--- One rule, applied at both ends: `ready_problems` asks it of every
--- item before a take (stale data already on the board), and `new
--- --repo` and `set --repo` ask it before the write lands (stale data
--- entering). A board whose origin does not resolve to a GitHub slug
--- has no owner to compare against and skips the rule — the same
--- local-only waiver the handover gate uses.
local gitslug = require("_work.gitslug")
local spec = require("_work.spec")
local store = require("_work.store")

--- The board's own GitHub owner — the owner half of `gitslug.slug`'s
--- reading of the origin remote — or nil when the origin is missing
--- or is not a GitHub remote.
--- @param s store.Store The store
--- @return string | nil The owner, as the remote spells it
local function board_owner(s: store.Store): string | nil
  local slugged, _err = gitslug.slug(s, nil)
  if slugged == nil then
    return nil
  end
  return slugged:match("^([^/]+)/")
end

--- The problem a `repo` earns under the owner rule, or nil when it
--- passes: unset, sharing the board's owner (case-insensitively, as
--- GitHub compares), named as the spec's read access, or asked on
--- a board with no owner to compare against. The problem names the
--- field, the value, and the repair: `gitboard set ID --repo` when
--- the item is already filed, the `--repo` flag itself when `new` is
--- about to file it (`id` is "").
--- @param s store.Store The store
--- @param repo string The item's repo field, "" when unset
--- @param body string The spec the rule reads the access declaration from
--- @param id string The item's full id, "" for an item not yet filed
--- @return string | nil The problem
local function repo_problem(s: store.Store, repo: string, body: string,
    id: string): string | nil
  if (repo or "") == "" then
    return nil
  end
  local owner = board_owner(s)
  if owner == nil then
    return nil
  end
  local repo_owner, name = repo:match("^([^/]+)/(.+)$")
  if repo_owner == nil or repo_owner:lower() == owner:lower() then
    return nil
  end
  if spec.declared_repos(body or "")[repo:lower()] then
    return nil
  end
  local repair = ("pass --repo %s/%s"):format(owner, name)
  if (id or "") ~= "" then
    repair = ("`gitboard set %s --repo %s/%s`"):format(id:sub(1, 8), owner, name)
  end
  return ("repo: %s is under %s, not this board's owner %s — a claiming "
    .. "session is granted the board's repositories, so the field most "
    .. "likely names a fork the session cannot reach; %s, or declare %s "
    .. "as the item's read access when the cross-owner target is "
    .. "deliberate")
  :format(repo, repo_owner, owner, repair, repo)
end

local record gitowner
  board_owner: function(s: store.Store): string | nil
  repo_problem: function(s: store.Store, repo: string, body: string,
  id: string): string | nil
end

local M: gitowner = {
  board_owner = board_owner,
  repo_problem = repo_problem,
}

return M
