--- CLI surface for caller-owned Git transport. `publish` renders prepared
--- leased pushes and `refresh` inspects already-fetched tracking refs. Only an
--- explicit `--execute` runs the exact ordinary Git argv being rendered; this
--- module never discovers or handles credentials.
local cache = require("_work.cache")
local gate = require("_work.gitgate")
local gitclaim = require("_work.gitclaim")
local prepared = require("_work.prepared")
local refs = require("_work.refs")
local store = require("_work.store")

--- Render one argv so it can be pasted into a POSIX shell without allowing a
--- refspec glob or unusual remote name to be reinterpreted.
--- @param argv {string} Argument vector, executable first
--- @return string Shell command
local function render_argv(argv: {string}): string
  local words: {string} = {}
  for _, word in ipairs(argv) do
    if word:match("^[A-Za-z0-9_./:@+=,-]+$") then
      words[#words + 1] = word
    else
      words[#words + 1] = "'" .. word:gsub("'", "'\"'\"'") .. "'"
    end
  end
  return table.concat(words, " ")
end

--- Resolve a transaction selector as an exact staging ref or an unambiguous
--- commit-id prefix. Empty selector lists mean every prepared transaction.
local record PushPlan
  id: string
  staging_ref: string
  argv: {string}
  --- Zero for ordinary transactions; claim plans carry their lease deadline.
  expires_at: integer
end

local function select_transactions(root: string, selectors: {string},
    remote: string): {PushPlan} | nil, string
  local transactions, err = prepared.list(root)
  if transactions == nil then return nil, err end
  local claims, cerr = gitclaim.list_prepared(root, remote)
  if claims == nil then return nil, cerr end
  local all: {PushPlan} = {}
  for _, tx in ipairs(transactions) do
    all[#all + 1] = {id = tx.id, staging_ref = tx.staging_ref,
      argv = prepared.push_argv(tx, remote), expires_at = 0}
  end
  for _, claim in ipairs(claims) do
    all[#all + 1] = {id = claim.new_sha, staging_ref = claim.staging_ref,
      argv = claim.push_argv, expires_at = claim.expires_at}
  end
  if #selectors == 0 then return all, "" end
  local out: {PushPlan} = {}
  local added: {string: boolean} = {}
  for _, selector in ipairs(selectors) do
    local matches: {PushPlan} = {}
    for _, plan in ipairs(all) do
      if plan.staging_ref == selector or plan.id == selector
      or plan.id:sub(1, #selector) == selector then
        matches[#matches + 1] = plan
      end
    end
    if #matches == 0 then
      return nil, ("no prepared transaction matches %s"):format(selector)
    end
    if #matches > 1 then
      return nil, ("prepared transaction prefix %s is ambiguous"):format(selector)
    end
    local plan = matches[1]
    if not added[plan.staging_ref] then
      added[plan.staging_ref] = true
      out[#out + 1] = plan
    end
  end
  return out, ""
end

--- Render or explicitly execute prepared pushes. Execution delegates
--- authentication entirely to ordinary Git.
local function cmd_publish(s: store.Store, selectors: {string}, remote: string,
    execute: boolean): integer
  if refs.board_mode(s.root) == "local" then
    return gate.verdict_line("publish", false,
      "REFUSED: a local-only board has no remote publication step")
  end
  local plans, err = select_transactions(s.root, selectors, remote)
  if plans == nil then return gate.verdict_line("publish", false, err) end
  if #plans == 0 then
    return gate.verdict_line("publish", true, "no prepared transactions")
  end
  local failed = 0
  for _, plan in ipairs(plans) do
    if plan.expires_at > 0 and plan.expires_at <= os.time() then
      local cleaned, cerr = refs.update_ref(s.root, plan.staging_ref,
        refs.ZERO_SHA, plan.id)
      failed = failed + 1
      if cleaned then
        io.stderr:write(("publish %s refused: prepared claim expired; staging "
            .. "receipt removed — prepare a fresh claim\n"):format(plan.id))
      else
        io.stderr:write(("publish %s refused: prepared claim expired; could "
            .. "not remove staging receipt: %s\n"):format(plan.id, cerr))
      end
    elseif execute then
      local ok, eerr = prepared.execute(s.root, plan.argv)
      if ok then
        print(("published: %s"):format(plan.id))
      else
        failed = failed + 1
        io.stderr:write(("publish %s failed: %s\n"):format(plan.id, eerr))
      end
    else
      print(render_argv(plan.argv))
    end
  end
  if failed > 0 then
    return gate.verdict_line("publish", false,
      ("%d of %d prepared transactions failed; staging refs remain")
      :format(failed, #plans))
  end
  if execute then
    gate.verdict_line("publish", true,
      ("CONFIRMATION PENDING: %d prepared transaction(s) pushed. Run "
        .. "`gitboard refresh --execute --remote %s`; a pushed claim is not "
        .. "safe to act on until refresh reports confirmed")
      :format(#plans, remote))
    return 2
  end
  return gate.verdict_line("publish", true,
    ("rendered %d exact leased push command(s); nothing executed")
    :format(#plans))
end

--- Reconcile staged transactions against local tracking refs. Bare refresh
--- also prints the exact caller-owned fetch; `--execute` runs it first.
local function cmd_refresh(s: store.Store, remote: string,
    execute: boolean): integer
  local mode = refs.board_mode(s.root)
  local fetch = prepared.fetch_argv(remote)
  if mode == "remote" then
    if execute then
      local ok, err = prepared.execute(s.root, fetch)
      if not ok then return gate.verdict_line("refresh", false, err) end
    else
      print(render_argv(fetch))
    end
  end
  local outcomes, err = prepared.refresh(s.root, remote)
  if outcomes == nil then return gate.verdict_line("refresh", false, err) end
  local confirmed, pending, lost = 0, 0, 0
  for _, outcome in ipairs(outcomes) do
    print(("%s %s: %s"):format(outcome.state,
        outcome.transaction.id, outcome.detail))
    if outcome.state == "confirmed" then confirmed = confirmed + 1
    elseif outcome.state == "pending" then pending = pending + 1
    else lost = lost + 1 end
  end
  local claims, cerr = gitclaim.list_prepared(s.root, remote)
  if claims == nil then return gate.verdict_line("refresh", false, cerr) end
  for _, claim in ipairs(claims) do
    local source = mode == "local" and claim.target_ref
    or gitclaim.remote_item_ref(remote, claim.id)
    local observed, oerr = refs.read_ref(s.root, source)
    if observed == nil then return gate.verdict_line("refresh", false, oerr) end
    if observed == claim.new_sha then
      local ok, ferr = gitclaim.confirm(s.root, source, claim)
      if not ok then return gate.verdict_line("refresh", false, ferr) end
      confirmed = confirmed + 1
      print(("confirmed %s: fetched item ref matches prepared claim"):format(
          claim.new_sha))
    elseif observed == claim.old_sha then
      pending = pending + 1
      print(("pending %s: fetched item ref still names the expected object")
        :format(claim.new_sha))
    else
      lost = lost + 1
      print(("lost-race %s: fetched item ref names %s, expected %s or %s")
        :format(claim.new_sha, observed, claim.old_sha, claim.new_sha))
    end
  end
  local rebuilt, rerr = cache.rebuild(s.root)
  if rebuilt == nil then return gate.verdict_line("refresh", false, rerr) end
  local _closed, _cerr = cache.close(rebuilt)
  local _sclosed, _serr = store.close(s)
  local detail = ("confirmed=%d pending=%d lost-race=%d; cache rebuilt")
  :format(confirmed, pending, lost)
  if mode == "remote" and not execute then
    detail = detail .. "; fetched refs were not changed"
  end
  if lost > 0 then return gate.verdict_line("refresh", false, detail) end
  if pending > 0 then
    gate.verdict_line("refresh", true, "CONFIRMATION PENDING: " .. detail)
    return 2
  end
  return gate.verdict_line("refresh", true, detail)
end

local record gittransport
  render_argv: function(argv: {string}): string
  cmd_publish: function(s: store.Store, selectors: {string}, remote: string,
  execute: boolean): integer
  cmd_refresh: function(s: store.Store, remote: string,
  execute: boolean): integer
end

local M: gittransport = {
  render_argv = render_argv,
  cmd_publish = cmd_publish,
  cmd_refresh = cmd_refresh,
}

return M
