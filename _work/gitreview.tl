--- `gitboard handoff ID...`: hand items to a fresh-context reviewer.
---
--- Named for the claim transfer it performs, not for the review itself:
--- `review` is already a doctrine topic (`gitboard help review`), and a
--- verb sharing that name makes its own help page unreachable.
---
--- The doctrine's requirement is one sentence — the verdict comes from a
--- subagent whose context never held the build — but satisfying it by hand
--- meant minting an identity, dropping the builder's claim, claiming under
--- the new one, publishing, refreshing, creating a worktree and rendering a
--- brief, one verb at a time. This composes that.
---
--- A worktree and a brief need the handoff CONFIRMED, which is only true
--- after the caller publishes and refreshes, so one invocation cannot do both
--- halves. The verb is idempotent and reads which half to do from the board:
--- items not yet held by the caller get the handoff prepared; items already
--- held get their worktree and brief.

local boardread = require("_work.boardread")
local repository_map = require("_work.repository_map")
local brief = require("_work.brief")
local claim = require("_work.claim")
local fs = require("cosmic.fs")
local claimsession = require("_work.claimsession")
local gate = require("_work.gitgate")
local gitworktree = require("_work.gitworktree")
local item = require("_work.item")
local stateclaim = require("_work.stateclaim")
local stateclaim_cli = require("_work.stateclaim_cli")
local store = require("_work.store")

--- Whether every named item is already held by this session, which is what
--- makes the brief half reachable. A mixed set is the caller running the verb
--- again before publishing the whole batch, so it stays in the handoff half
--- and the refusals name which ones.
local function all_held(s: store.Store, ids: {string}, caller: string): boolean
  local view = boardread.list(s.root, s.state_head)
  if view == nil then return false end
  local now = os.time()
  for _, id in ipairs(ids) do
    local held = view.claims_by_id[id]
    if held == nil or held.holder ~= caller
    or claim.status(stateclaim.state(held), now) ~= "active" then
      return false
    end
  end
  return true
end

--- The brief half: one worktree per item that needs one, then the filled
--- brief. `brief review` refuses on its own when the claim is not a
--- reviewer's, so this never has to re-derive that rule.
local function briefs(s: store.Store, ids: {string}, caller: string,
    out: string, tree: string, command: string, cwd: string,
    fetch: boolean, worktrees: boolean): integer
  for _, id in ipairs(ids) do
    -- Phase two is re-runnable: a checkout left by an earlier attempt is
    -- the one the reviewer should use, and `cmd_worktree` refuses rather
    -- than reusing, so skip it when the path is already there.
    local existing = false
    local it = store.load(s, id)
    if it ~= nil then
      local view = boardread.list(s.root, s.state_head)
      local held = view ~= nil and view.claims_by_id[id] or nil
      local checkout = held ~= nil
      and repository_map.resolve(s.root, it.repo or "", "") or nil
      if checkout ~= nil and held ~= nil then
        existing = fs.is_dir(claim.worktree(checkout,
            claim.branch(id, held.id)))
      end
    end
    if worktrees and not existing then
      -- A review checkout takes no receipt (those are builder-only), and
      -- `cmd_worktree` refuses the invocation flags without one — they
      -- belong to the brief below, not here.
      local code = gitworktree.cmd_worktree(s, id, caller, "", {}, true, false,
        nil, nil, nil, nil, fetch)
      if code ~= 0 then
        return gate.verdict_line("handoff", false,
          ("could not prepare %s's checkout"):format(id:sub(-8)))
      end
    end
    local target = out
    if out ~= "" and #ids > 1 then target = out .. "/" .. id:sub(-8) .. ".txt" end
    -- No caller: `--session` on a brief names a BUILDER presenting a
    -- receipt. A review brief reads the reviewing claim off the board,
    -- which the handoff above has already put there.
    local code = brief.cmd_brief(s, "review", id, target, tree, nil, nil,
      command, cwd)
    if code ~= 0 then
      return gate.verdict_line("handoff", false,
        ("could not render %s's brief"):format(id:sub(-8)))
    end
  end
  return gate.verdict_line("handoff", true,
    ("%d brief(s) ready under session %s"):format(#ids, caller))
end

--- @param s store.Store The board
--- @param args {string} Item ids or handles, as the caller typed them
--- @param resolve function The dispatcher's own id resolver
--- @param remote string The remote the caller expects to publish to
--- @param explicit_session string The reviewer identity, "" to mint one
--- @param out string Where briefs are written, "" for stdout
--- @param tree string Passed to `brief --tree`
--- @param command string The caller's own gitboard invocation, for the brief
--- @param cwd string That invocation's cwd
--- @param fetch boolean Passed to `worktree --fetch`
--- @param worktrees boolean Whether the brief half creates checkouts
--- @return integer The verdict line's exit status
local function cmd_review(s: store.Store, args: {string},
    resolve: function(string): string | nil, string,
    remote: string, explicit_session: string, out: string, tree: string,
    command: string, cwd: string, fetch: boolean,
    worktrees: boolean): integer
  if #args == 0 then
    return gate.verdict_line("handoff", false,
      "REFUSED: at least one ID is required")
  end
  local ids: {string} = {}
  for _, given in ipairs(args) do
    local full, rerr = resolve(given)
    if full == nil then return gate.verdict_line("handoff", false, rerr) end
    ids[#ids + 1] = full
  end
  local caller = explicit_session
  local minted = false
  if caller == "" then
    caller = claimsession.mint()
    minted = true
  end
  if all_held(s, ids, caller) then
    return briefs(s, ids, caller, out, tree, command, cwd, fetch, worktrees)
  end
  if minted then
    -- A minted identity that never reaches the caller is unusable: the
    -- second half needs the same one, and nothing else records it.
    print(("reviewer session %s — pass it to --session on the next call")
      :format(caller))
  end
  local all, aerr = store.list(s)
  if all == nil then return gate.verdict_line("handoff", false, aerr) end
  local code = stateclaim_cli.run(s, ids, all, "handoff", caller, remote,
    false, "", false, "handoff",
    function(_it: item.Item): string | nil, string return "", "" end)
  if code == 0 or code == 2 then
    local rest = table.concat(ids, " ")
    print(("then: gitboard handoff %s --session %s%s"):format(rest, caller,
        out ~= "" and (" --out " .. out) or ""))
  end
  return code
end

local record gitreview
  cmd_review: function(s: store.Store, args: {string},
  resolve: function(string): string | nil, string,
  remote: string, explicit_session: string, out: string, tree: string,
  command: string, cwd: string, fetch: boolean, worktrees: boolean): integer
end

local M: gitreview = {cmd_review = cmd_review}
return M
