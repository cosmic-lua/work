--- CLI surface for caller-owned Git transport. `publish` renders prepared
--- leased pushes and `refresh` inspects already-fetched tracking refs. Only an
--- explicit `--execute` runs the exact ordinary Git argv being rendered; this
--- module never discovers or handles credentials.
local cache = require("_work.cache")
local fs = require("cosmic.fs")
local gate = require("_work.gitgate")
local gitclaim = require("_work.gitclaim")
local gitdraft = require("_work.gitdraft")
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
  staging_refs: {string}
  match_ids: {string}
  argv: {string}
  --- Zero for ordinary transactions; claim plans carry their lease deadline.
  expires_at: integer
  updates: {prepared.Update}
  kind: string
  bound_remote: string
  claim: gitclaim.Prepared | nil
end

local function is_claim_transaction(tx: prepared.Transaction): boolean
  for _, update in ipairs(tx.updates) do
    if update.ref:match("^refs/heads/claim%-batches/") then return true end
  end
  return false
end

local function select_transactions(root: string, selectors: {string},
    remote: string): {PushPlan} | nil, string
  local transactions, err = prepared.list(root)
  if transactions == nil then return nil, err end
  local all: {PushPlan} = {}
  for _, tx in ipairs(transactions) do
    if is_claim_transaction(tx) then
      local claim_plan, cerr = gitclaim.from_transaction(root, tx)
      if claim_plan == nil then return nil, cerr end
      local match_ids: {string} = {tx.id, claim_plan.id,
        claim_plan.batch.commit}
      for _, member in ipairs(claim_plan.members) do
        match_ids[#match_ids + 1] = member.id
        match_ids[#match_ids + 1] = member.new_sha
      end
      all[#all + 1] = {id = claim_plan.id,
        staging_refs = {tx.staging_ref}, match_ids = match_ids, argv = {},
        expires_at = claim_plan.deadline, updates = tx.updates, kind = "claim",
        bound_remote = claim_plan.batch.remote, claim = claim_plan}
    else
      all[#all + 1] = {id = tx.id, staging_refs = {tx.staging_ref},
        match_ids = {tx.id}, claim = nil,
        argv = prepared.push_argv(tx, remote), expires_at = 0,
        updates = tx.updates, kind = "transaction", bound_remote = ""}
    end
  end
  local drafts, derr = gitdraft.list(root)
  if drafts == nil then return nil, derr end
  for _, draft in ipairs(drafts) do
    local updates = gitdraft.plan(draft)
    if #updates > 0 then
      local tx: prepared.Transaction = {id = draft.id,
        staging_ref = draft.staging_ref, manifest = draft.manifest,
        updates = updates}
      all[#all + 1] = {id = draft.id, staging_refs = {draft.staging_ref},
        match_ids = {draft.id}, argv = prepared.push_argv(tx, remote),
        expires_at = 0, updates = updates, kind = "draft",
        bound_remote = draft.remote, claim = nil}
    end
  end
  if #selectors == 0 then return all, "" end
  local out: {PushPlan} = {}
  local added: {string: boolean} = {}
  for _, selector in ipairs(selectors) do
    local matches: {PushPlan} = {}
    for _, plan in ipairs(all) do
      local matched = plan.id == selector or plan.id:sub(1, #selector) == selector
      for _, ref in ipairs(plan.staging_refs) do
        if ref == selector then matched = true end
      end
      for _, id in ipairs(plan.match_ids) do
        if id == selector or id:sub(1, #selector) == selector then matched = true end
      end
      if matched then matches[#matches + 1] = plan end
    end
    if #matches == 0 then
      return nil, ("no prepared transaction matches %s"):format(selector)
    end
    if #matches > 1 then
      return nil, ("prepared transaction prefix %s is ambiguous"):format(selector)
    end
    local plan = matches[1]
    if not added[plan.id] then
      added[plan.id] = true
      out[#out + 1] = plan
    end
  end
  return out, ""
end

--- The URL the configured remote resolves to in this checkout — the
--- repository an executed publish actually writes to, and the one fact
--- neither the rendered argv nor the `published:` line carries.
--- `--push` falls back to the fetch URL when no separate push URL is
--- configured, so it is never less correct than the plain read.
--- @param s store.Store The store
--- @param remote string The remote name the push argv names
--- @return string The URL, or a readable stand-in when git cannot read it
local function remote_push_url(s: store.Store, remote: string): string
  local r = store.git(s, {"remote", "get-url", "--push", remote})
  if r == nil or not r.ok then
    return ("unreadable (no %s remote in this checkout)"):format(remote)
  end
  return (r.stdout:gsub("%s+$", ""))
end

--- Render or explicitly execute prepared pushes. Execution delegates
--- authentication entirely to ordinary Git.
local function cmd_publish(s: store.Store, selectors: {string}, remote: string,
    execute: boolean): integer
  local plans, err = select_transactions(s.root, selectors, remote)
  if plans == nil then return gate.verdict_line("publish", false, err) end
  if #plans == 0 then
    return gate.verdict_line("publish", true, "no prepared transactions")
  end
  if #plans > 1 then
    return gate.verdict_line("publish", false,
      "REFUSED: select exactly one prepared transaction or draft; one publish is one atomic push")
  end
  if plans[1].bound_remote ~= "" and plans[1].bound_remote ~= remote then
    return gate.verdict_line("publish", false,
      ("REFUSED: prepared %s is bound to remote %s, not %s")
      :format(plans[1].id, plans[1].bound_remote, remote))
  end
  if refs.board_mode(s.root) == "local" then
    local plan = plans[1]
    if plan.kind ~= "draft" then
      return gate.verdict_line("publish", false,
        "REFUSED: a local-only board has no remote publication step")
    end
    if not execute then
      return gate.verdict_line("publish", true,
        "local simulation ready; run the same command with --execute to apply its atomic ref transaction")
    end
    local local_updates: {refs.RefUpdate} = {}
    for _, u in ipairs(plan.updates) do
      local_updates[#local_updates + 1] = {ref = u.ref, expected = u.expected,
        next = u.next}
    end
    local applied, aerr = refs.update_refs_atomic(s.root, local_updates)
    if not applied then return gate.verdict_line("publish", false, aerr) end
    local draft, derr = gitdraft.open(s.root, plan.id)
    if draft == nil then return gate.verdict_line("publish", false, derr) end
    local removed, rerr = gitdraft.abort(s.root, draft)
    if not removed then return gate.verdict_line("publish", false, rerr) end
    return gate.verdict_line("publish", true,
      ("local simulation applied atomically: draft=%s refs=%d"):format(
        plan.id, #plan.updates))
  end
  print(("target: dir=%s remote=%s url=%s"):format(
      fs.absolute_path(s.root), remote, remote_push_url(s, remote)))
  local failed = 0
  for _, plan in ipairs(plans) do
    local argv = plan.argv
    local claim_err = ""
    if plan.claim ~= nil then
      local claim_argv, aerr = gitclaim.push_argv(plan.claim, remote)
      if claim_argv ~= nil then argv = claim_argv else claim_err = aerr end
    end
    if claim_err ~= "" then
      local staging_ref = plan.staging_refs[1]
      local sha, serr = refs.read_ref(s.root, staging_ref)
      if sha == nil then return gate.verdict_line("publish", false, serr) end
      local cleaned, cerr = refs.update_ref(s.root, staging_ref,
        refs.ZERO_SHA, sha)
      failed = failed + 1
      if cleaned then
        io.stderr:write(("publish %s refused: %s; staging receipt removed — "
            .. "prepare a fresh claim\n"):format(plan.id, claim_err))
      else
        io.stderr:write(("publish %s refused: %s; could not remove staging "
            .. "receipt: %s\n"):format(plan.id, claim_err, cerr))
      end
    elseif execute then
      local ok, eerr = prepared.execute(s.root, argv)
      if ok then
        print(("published: %s"):format(plan.id))
      else
        failed = failed + 1
        io.stderr:write(("publish %s failed; atomic batch acquired nothing: %s\n")
          :format(plan.id, eerr))
      end
    else
      print(render_argv(argv))
    end
  end
  if failed > 0 then
    return gate.verdict_line("publish", false,
      ("%d of %d prepared transaction batches failed; staging refs remain")
      :format(failed, #plans))
  end
  if execute then
    gate.verdict_line("publish", true,
      ("CONFIRMATION PENDING: %d prepared transaction batch(es) pushed. Run "
        .. "`gitboard refresh --execute --remote %s`; a pushed claim is not "
        .. "safe to act on until refresh reports confirmed")
      :format(#plans, remote))
    return 2
  end
  return gate.verdict_line("publish", true,
    ("rendered %d exact atomic leased push command(s); nothing executed")
    :format(#plans))
end

--- Reconcile staged transactions against local tracking refs. Bare refresh
--- also prints the exact caller-owned fetch; `--execute` runs it first.
local function cmd_refresh(s: store.Store, remote: string,
    execute: boolean): integer
  local mode = refs.board_mode(s.root)
  -- A claim transaction's batch object records the remote whose canonical
  -- item tips were leased. Inspect that binding before `prepared.refresh`
  -- compares (and may confirm and remove) any receipt against tracking refs
  -- from the caller-selected remote.
  local staged, serr = prepared.list(s.root)
  if staged == nil then return gate.verdict_line("refresh", false, serr) end
  for _, tx in ipairs(staged) do
    if is_claim_transaction(tx) then
      local claim_plan, cerr = gitclaim.from_transaction(s.root, tx)
      if claim_plan == nil then return gate.verdict_line("refresh", false, cerr) end
      if claim_plan.batch.remote ~= remote then
        return gate.verdict_line("refresh", false,
          ("REFUSED: prepared claim batch %s is bound to remote %s, not %s")
          :format(claim_plan.id, claim_plan.batch.remote, remote))
      end
    end
  end
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
  local confirmed, pending, lost, expired = 0, 0, 0, 0
  local moved_ids: {string} = {}
  for _, outcome in ipairs(outcomes) do
    if is_claim_transaction(outcome.transaction) then
      local claim_plan, cerr = gitclaim.from_transaction(s.root,
        outcome.transaction)
      if claim_plan == nil then return gate.verdict_line("refresh", false, cerr) end
      local members = #claim_plan.members
      if outcome.state == "confirmed" then
        if claim_plan.batch.action == "drop" then
          confirmed = confirmed + 1
          print(("confirmed claim batch %s: items=%d; claims dropped; no "
              .. "claim authority remains"):format(claim_plan.id, members))
        else
          local authority_until = 0
          for _, member in ipairs(claim_plan.members) do
            if authority_until == 0 or member.expires_at < authority_until then
              authority_until = member.expires_at
            end
          end
          if authority_until <= os.time() then
            expired = expired + 1
            print(("confirmed claim batch %s: items=%d; EXPIRED — no "
                .. "authority; reacquire before work")
              :format(claim_plan.id, members))
          else
            confirmed = confirmed + 1
            print(("confirmed claim batch %s: items=%d; authority active "
                .. "until %d"):format(claim_plan.id, members, authority_until))
          end
        end
      elseif outcome.state == "pending" then
        pending = pending + 1
        print(("pending claim batch %s: %s; no claim authority confirmed")
          :format(claim_plan.id, outcome.detail))
      else
        lost = lost + 1
        for _, member in ipairs(claim_plan.members) do
          moved_ids[#moved_ids + 1] = member.id
        end
        print(("lost-race claim batch %s: %s; no claim authority confirmed")
          :format(claim_plan.id, outcome.detail))
      end
    else
      print(("%s %s: %s"):format(outcome.state,
          outcome.transaction.id, outcome.detail))
      if outcome.state == "confirmed" then confirmed = confirmed + 1
      elseif outcome.state == "pending" then pending = pending + 1
      else lost = lost + 1 end
    end
  end
  local drafts, derr = gitdraft.list(s.root)
  if drafts == nil then return gate.verdict_line("refresh", false, derr) end
  for _, draft in ipairs(drafts) do
    if draft.remote ~= remote then goto continue_draft end
    local next_count, expected_count = 0, 0
    local conflicts: {string} = {}
    local updates = gitdraft.plan(draft)
    for _, u in ipairs(updates) do
      local source = mode == "local" and u.ref or refs.tracking_ref(u.ref, remote)
      if source == nil then
        return gate.verdict_line("refresh", false, "could not map draft ref " .. u.ref)
      end
      local observed, oerr = refs.read_ref(s.root, source)
      if observed == nil then return gate.verdict_line("refresh", false, oerr) end
      if observed == u.next then next_count = next_count + 1
      elseif observed == u.expected then expected_count = expected_count + 1
      else conflicts[#conflicts + 1] = u.ref end
    end
    if #updates > 0 and next_count == #updates then
      local removed, rerr = gitdraft.abort(s.root, draft)
      if not removed then return gate.verdict_line("refresh", false, rerr) end
      confirmed = confirmed + 1
      print(("confirmed draft %s: every fetched ref matches its final tip"):format(draft.id))
    elseif #conflicts > 0 or (next_count > 0 and expected_count > 0) then
      lost = lost + 1
      local detail = #conflicts > 0 and table.concat(conflicts, " ")
      or "atomic publication is partially visible"
      print(("lost-race draft %s: %s"):format(draft.id, detail))
    else
      pending = pending + 1
      print(("pending draft %s: fetched refs still name the frozen baseline")
        :format(draft.id))
    end
    ::continue_draft::
  end
  local rebuilt, rerr = cache.rebuild(s.root)
  if rebuilt == nil then return gate.verdict_line("refresh", false, rerr) end
  local _closed, _cerr = cache.close(rebuilt)
  local _sclosed, _serr = store.close(s)
  local detail = ("confirmed=%d pending=%d lost-race=%d expired=%d; cache rebuilt")
  :format(confirmed, pending, lost, expired)
  if mode == "remote" and not execute then
    detail = detail .. "; fetched refs were not changed"
  end
  if #moved_ids > 0 then
    table.sort(moved_ids)
    detail = detail .. "; moved IDs: " .. table.concat(moved_ids, " ")
    .. "; fetch current state, remove or replace them, then retry the set"
  end
  if lost > 0 or expired > 0 then
    return gate.verdict_line("refresh", false, detail)
  end
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
