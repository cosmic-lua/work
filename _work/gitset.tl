--- set: repair an item's own destination facts directly — `title`,
--- `repo`, `base`, and the two declared lists `touches` and `access` —
--- the fields no other verb moves once an item is filed. Split out of
--- `_work.gitgraph`, which sits against the file cap and holds the
--- GRAPH verbs proper (`new`, `attach`); `set` moves no edge, and
--- `gitgraph` re-exports it so every caller keeps resolving.
---
--- Flow fields (claim, pr, verdict, resolution, parent, key) have their
--- own verbs and gates; `set` refuses them by not existing for them —
--- the dispatcher's flag spec never declares those long names on this
--- command, so passing one is an unrecognized-flag refusal before `set`
--- is ever called. `depends_on` is the one declared field that is NOT
--- here: it has its own verb (`_work.gitdepend`), because the cycle
--- check belongs in one place.
---
--- Every passed field lands in canonical order (title, repo, base,
--- touches, access) regardless of flag order, so the commit subject —
--- `set <id8> <field>...` — is deterministic and names only WHICH
--- fields moved; the values ride in the diff, not the subject, because
--- a title is long and a diff already shows what changed.
---
--- A list flag REPLACES the field rather than appending to it: one
--- mechanism, the same one the scalar flags have — `set` repairs a
--- field to what the caller states, and repeating the flag builds the
--- replacement. An empty list clears the field; the CLI has no spelling
--- for one, the same way `--repo ""` and `--base ""` refuse rather than
--- clearing, so clearing is a caller of this function.
local gate = require("_work.gitgate")
local item = require("_work.item")
local owner = require("_work.gitowner")
local spec = require("_work.spec")
local store = require("_work.store")

--- @param s store.Store The store
--- @param id string The item to repair
--- @param title string | nil The new title, nil to leave it unchanged
--- @param repo string | nil The new repo, nil to leave it unchanged
--- @param new_base string | nil The new base branch, nil to leave it unchanged
--- @param touches {string} | nil The whole new `touches` list, nil to
--- leave it unchanged and an empty list to clear it
--- @param access {string} | nil The whole new `access` list, on the
--- same nil/empty rule as `touches`
--- @return integer Exit code
local function cmd_set(s: store.Store, id: string, title: string | nil,
    repo: string | nil, new_base: string | nil, claim_session?: string,
    force?: boolean, why?: string, touches?: {string},
    access?: {string}): integer
  local frc, rsn = force or false, why or ""
  local forced = gate.force_refusal(frc, rsn)
  if forced then
    return gate.verdict_line("set", false, "REFUSED: " .. forced)
  end
  if title == nil and repo == nil and new_base == nil and touches == nil
  and access == nil then
    return gate.verdict_line("set", false,
      "REFUSED: set needs at least one of --title, --repo, --base, "
      .. "--touches, --access")
  end
  local it, lerr = store.load(s, id)
  if it == nil then
    return gate.verdict_line("set", false, lerr)
  end
  if not item.is_open(it) then
    return gate.verdict_line("set", false,
      ("REFUSED: %s is done (%s) — a finished item's facts are history, "
        .. "not a repair target"):format(id:sub(1, 8), it.resolution))
  end
  local fields: {string} = {}
  if title ~= nil then
    if title:match("%S") == nil then
      return gate.verdict_line("set", false, "REFUSED: --title cannot be empty")
    end
    it.title = title
    fields[#fields + 1] = "title"
  end
  if repo ~= nil then
    if repo:match("%S") == nil then
      return gate.verdict_line("set", false,
        "REFUSED: --repo cannot be empty — clearing it is not supported; "
        .. "set --repo <owner>/<name> to change it")
    end
    local foreign = owner.repo_problem(s, repo,
      spec.document(store.read_spec(s, id)), id)
    if foreign then
      return gate.verdict_line("set", false, "REFUSED: " .. foreign)
    end
    it.repo = repo
    fields[#fields + 1] = "repo"
  end
  if new_base ~= nil then
    if new_base:match("%S") == nil then
      return gate.verdict_line("set", false,
        "REFUSED: --base cannot be empty — clearing it is not supported; "
        .. "set --base <branch> to change it")
    end
    it.base = new_base
    fields[#fields + 1] = "base"
  end
  if touches ~= nil then
    it.touches = touches
    fields[#fields + 1] = "touches"
  end
  if access ~= nil then
    it.access = access
    fields[#fields + 1] = "access"
  end
  local bad = item.problems(it)
  if #bad > 0 then
    return gate.verdict_line("set", false, table.concat(bad, "; "))
  end
  local ok, err = gate.commit_and_publish(s, it, nil,
    ("set %s %s%s"):format(id:sub(1, 8), table.concat(fields, " "),
      gate.forced_suffix(frc, rsn)), "set", nil, claim_session, false, frc, rsn)
  if not ok then
    return gate.verdict_line("set", false, err)
  end
  if store.is_noop(err) then
    return gate.verdict_line("set", true, err)
  end
  return gate.verdict_line("set", true,
    ("%s: %s updated"):format(id:sub(1, 8), table.concat(fields, ", ")))
end

local record gitset
  cmd_set: function(s: store.Store, id: string, title: string | nil,
  repo: string | nil, new_base: string | nil, claim_session?: string,
  force?: boolean, why?: string, touches?: {string},
  access?: {string}): integer
end

local M: gitset = {
  cmd_set = cmd_set,
}

return M
